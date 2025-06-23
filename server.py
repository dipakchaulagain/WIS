from http.server import SimpleHTTPRequestHandler, HTTPServer
import json
import os
import glob
from datetime import datetime

class RequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.dirname(os.path.abspath(__file__)), **kwargs)
    
    def do_GET(self):
        if self.path == '/api/assets':
            self.handle_assets()
        else:
            super().do_GET()
    
    def handle_assets(self):
        records = []
        for filepath in glob.glob('Records/*.json'):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    # Extract timestamp from filename if not in JSON
                    if 'Timestamp' not in data:
                        filename = os.path.basename(filepath)
                        try:
                            dt_part = filename.split('_')[-1].replace('.json', '')
                            data['Timestamp'] = datetime.strptime(dt_part, "%Y-%m-%d_%H_%M_%S").isoformat()
                        except:
                            data['Timestamp'] = datetime.now().isoformat()
                    records.append(data)
            except (json.JSONDecodeError, UnicodeDecodeError) as e:
                print(f"Error reading {filepath}: {str(e)}")
                continue
        
        # Sort by timestamp (newest first)
        records.sort(key=lambda x: x['Timestamp'], reverse=True)
        
        # Group by serial number, keeping only the latest
        assets_map = {}
        for record in records:
            sn = record.get('AssetInformation', {}).get('SerialNumber')
            if sn and (sn not in assets_map or 
                       record['Timestamp'] > assets_map[sn]['Timestamp']):
                assets_map[sn] = record
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(list(assets_map.values())).encode())

if __name__ == '__main__':
    port = 8000
    server = HTTPServer(('localhost', port), RequestHandler)
    print(f'Server running at http://localhost:{port}')
    print('Serving from:', os.path.dirname(os.path.abspath(__file__)))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
        print("\nServer stopped")