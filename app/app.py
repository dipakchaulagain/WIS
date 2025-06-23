from flask import Flask, jsonify, send_from_directory, render_template
import os
import json

app = Flask(__name__, static_folder='static', template_folder='templates')

# List .json files and prepare data for list view
@app.route('/')
def index():
    try:
        records_dir = os.path.abspath(os.path.join(os.getcwd(), '..', 'Records'))
        if not os.path.exists(records_dir):
            return render_template('list.html', assets=[], asset_count=0)

        files = os.listdir(records_dir)
        json_files = [f for f in files if f.endswith('.json')]
        
        # Parse filenames to get latest per owner
        file_map = {}
        for filename in json_files:
            regex = r'^SystemInfo_(.+)_(\d{4}-\d{2}-\d{2}_\d{2}_\d{2}_\d{2})\.json$'
            import re
            match = re.match(regex, filename)
            if match:
                owner_name = match.group(1).replace('_', ' ')
                timestamp = match.group(2).replace('_', ':')
                current = file_map.get(owner_name, {'timestamp': ''})
                if not current['timestamp'] or timestamp > current['timestamp']:
                    file_map[owner_name] = {'filename': filename, 'timestamp': timestamp}
        
        # Fetch asset data
        assets = []
        for owner, info in file_map.items():
            try:
                with open(os.path.join(records_dir, info['filename']), 'r') as f:
                    data = json.load(f)
                    data['filename'] = info['filename']  # Add filename for detail link
                    assets.append(data)
            except Exception as e:
                print(f"Error reading {info['filename']}: {e}")
        
        return render_template('list.html', assets=assets, asset_count=len(assets))
    except Exception as e:
        print(f"Error listing files: {e}")
        return render_template('list.html', assets=[], asset_count=0)

# Serve individual asset details
@app.route('/asset/<filename>')
def asset_detail(filename):
    try:
        records_dir = os.path.abspath(os.path.join(os.getcwd(), '..', 'Records'))
        file_path = os.path.join(records_dir, filename)
        if not os.path.exists(file_path):
            return render_template('detail.html', error="Asset not found"), 404
        with open(file_path, 'r') as f:
            data = json.load(f)
        return render_template('detail.html', asset=data)
    except Exception as e:
        print(f"Error serving file {filename}: {e}")
        return render_template('detail.html', error="Error loading asset"), 404

# API for sync button
@app.route('/records/list')
def list_files():
    try:
        records_dir = os.path.abspath(os.path.join(os.getcwd(), '..', 'Records'))
        if not os.path.exists(records_dir):
            return jsonify([])
        files = os.listdir(records_dir)
        json_files = [f for f in files if f.endswith('.json')]
        return jsonify(json_files)
    except Exception as e:
        print(f"Error listing files: {e}")
        return jsonify([])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)