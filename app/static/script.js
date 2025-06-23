async function fetchFileList() {
    try {
        const response = await fetch('/records/list', {
            headers: { 'Accept': 'application/json' }
        });
        if (!response.ok) {
            throw new Error(`Failed to fetch file list: ${response.status} ${response.statusText}`);
        }
        const data = await response.json();
        if (!Array.isArray(data)) {
            throw new Error('File list response is not an array');
        }
        return data.filter(file => file.endsWith('.json'));
    } catch (error) {
        console.error('Error fetching file list:', error);
        return [];
    }
}

function parseFilename(filename) {
    const regex = /^SystemInfo_(.+)_(\d{4}-\d{2}-\d{2}_\d{2}_\d{2}_\d{2})\.json$/;
    const match = filename.match(regex);
    if (!match) return null;
    return {
        ownerName: match[1].replace(/_/g, ' '),
        timestamp: match[2].replace(/_/g, ':'),
        filename: filename
    };
}

function getLatestFiles(fileList) {
    const fileMap = new Map();
    fileList.forEach(filename => {
        const parsed = parseFilename(filename);
        if (parsed) {
            const current = fileMap.get(parsed.ownerName);
            if (!current || new Date(parsed.timestamp.replace(/:/g, '-')) > new Date(current.timestamp.replace(/:/g, '-'))) {
                fileMap.set(parsed.ownerName, parsed);
            }
        }
    });
    return Array.from(fileMap.values());
}

async function syncAssets() {
    const syncDataBtn = document.getElementById('syncDataBtn');
    syncDataBtn.disabled = true;
    syncDataBtn.innerHTML = `
        <svg class="w-4 h-4 animate-spin mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.582m0 0a8.001 8.001 0 01-15.356-2m15.356 2H15"></path>
        </svg>
        <span>Syncing...</span>
    `;

    try {
        const fileList = await fetchFileList();
        const latestFiles = getLatestFiles(fileList);
        const assets = [];
        for (const file of latestFiles) {
            try {
                const response = await fetch(`/asset/${file.filename}`);
                if (response.ok) {
                    const html = await response.text();
                    // Update page with new list
                    document.body.innerHTML = html;
                }
            } catch (error) {
                console.error(`Error fetching ${file.filename}:`, error);
            }
        }
    } catch (error) {
        console.error('Error syncing assets:', error);
    }

    // Restore button state
    syncDataBtn.disabled = false;
    syncDataBtn.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.582m0 0a8.001 8.001 0 01-15.356-2m15.356 2H15"></path>
        </svg>
        <span>Sync Data</span>
    `;
}

document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('searchInput');
    const assetItems = document.getElementById('assetItems');
    const assetCount = document.getElementById('assetCount');
    const ownerNameDisplay = document.getElementById('ownerNameDisplay');
    const ownerInitials = document.getElementById('ownerInitials');
    const timestampDisplay = document.getElementById('timestampDisplay');

    // Store initial assets for client-side filtering
    const initialAssets = Array.from(assetItems.children).map(li => {
        const hostname = li.querySelector('h3').textContent;
        const ownerName = li.querySelector('.font-medium').textContent;
        const manufacturer = li.querySelector('p.text-sm.text-gray-500').textContent.split(' • ')[0].split(' ')[0];
        const model = li.querySelector('p.text-sm.text-gray-500').textContent.split(' • ')[0].split(' ').slice(1).join(' ');
        const os = li.querySelector('p.text-sm.text-gray-500').textContent.split(' • ')[1];
        return { AssetInformation: { Hostname: hostname, Manufacturer: manufacturer, Model: model, OS: os }, OwnerName: ownerName };
    });

    // Search functionality
    searchInput.addEventListener('input', () => {
        const query = searchInput.value.trim().toLowerCase();
        const filteredAssets = initialAssets.filter(asset => asset.OwnerName.toLowerCase().includes(query));
        
        assetItems.innerHTML = '';
        if (filteredAssets.length === 0) {
            assetItems.innerHTML = '<li class="p-6 text-red-600">No asset data found.</li>';
            ownerNameDisplay.textContent = 'No Owner';
            ownerInitials.textContent = '--';
            timestampDisplay.textContent = 'Last updated: Never';
            assetCount.textContent = '0 assets';
            return;
        }

        filteredAssets.forEach(asset => {
            const li = document.createElement('li');
            li.className = 'p-6 hover:bg-gray-50 cursor-pointer';
            li.innerHTML = `
                <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-4">
                        <div class="p-3 bg-indigo-100 rounded-lg">
                            <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                            </svg>
                        </div>
                        <div>
                            <h3 class="text-lg font-semibold text-gray-900">${asset.AssetInformation.Hostname}</h3>
                            <p class="text-sm text-gray-500">${asset.AssetInformation.Manufacturer} ${asset.AssetInformation.Model} • ${asset.AssetInformation.OS}</p>
                        </div>
                    </div>
                    <div class="flex items-center space-x-6">
                        <div class="text-right">
                            <p class="text-sm text-gray-500">Owner</p>
                            <p class="font-medium">${asset.OwnerName}</p>
                        </div>
                        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                        </svg>
                    </div>
                </div>
            `;
            assetItems.appendChild(li);
        });

        assetCount.textContent = `${filteredAssets.length} asset${filteredAssets.length !== 1 ? 's' : ''}`;
        ownerNameDisplay.textContent = filteredAssets[0].OwnerName;
        ownerInitials.textContent = filteredAssets[0].OwnerName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase();
        timestampDisplay.textContent = `Last updated: ${filteredAssets[0].Timestamp || 'Unknown'}`;
    });

    // Sync button
    document.getElementById('syncDataBtn').addEventListener('click', syncAssets);
});