async function fetchFileList() {
    try {
        const response = await fetch('/Records', {
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

async function fetchAssetData() {
    const fileList = await fetchFileList();
    const latestFiles = getLatestFiles(fileList);
    const assetData = [];
    for (const file of latestFiles) {
        try {
            const response = await fetch(`/Records/${file.filename}`);
            if (response.ok) {
                const data = await response.json();
                assetData.push(data);
            }
        } catch (error) {
            console.error(`Error fetching ${file.filename}:`, error);
        }
    }
    return assetData;
}

async function initializeApp() {
    const syncDataBtn = document.getElementById('syncDataBtn');
    const listViewBtn = document.getElementById('listViewBtn');
    const detailViewBtn = document.getElementById('detailViewBtn');
    const assetList = document.getElementById('assetList');
    const assetDetail = document.getElementById('assetDetail');
    const assetItems = document.getElementById('assetItems');
    const ownerNameDisplay = document.getElementById('ownerNameDisplay');
    const timestampDisplay = document.getElementById('timestampDisplay');
    const ownerInitials = document.getElementById('ownerInitials');

    async function loadAndDisplayAssets() {
        const assetData = await fetchAssetData();
        if (!assetData.length) {
            assetItems.innerHTML = '<li class="p-6 text-red-600">No asset data found.</li>';
            ownerNameDisplay.textContent = '';
            ownerInitials.textContent = '';
            timestampDisplay.textContent = 'Last updated: Never';
            return;
        }

        // Display asset list
        function showAssetList() {
            assetList.classList.remove('hidden');
            assetDetail.classList.add('hidden');
            listViewBtn.classList.add('hidden');
            detailViewBtn.classList.add('hidden');

            assetItems.innerHTML = '';
            assetData.forEach(data => {
                const item = document.createElement('li');
                item.className = 'p-6 hover:bg-gray-50 cursor-pointer';
                item.innerHTML = `
                    <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-4">
                            <div class="p-3 bg-indigo-100 rounded-lg">
                                <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                </svg>
                            </div>
                            <div>
                                <h3 class="text-lg font-semibold text-gray-900">${data.AssetInformation.Hostname}</h3>
                                <p class="text-sm text-gray-500">${data.AssetInformation.Manufacturer} ${data.AssetInformation.Model} • ${data.AssetInformation.OS}</p>
                            </div>
                        </div>
                        <div class="flex items-center space-x-6">
                            <div class="text-right">
                                <p class="text-sm text-gray-500">Owner</p>
                                <p class="font-medium">${data.OwnerName}</p>
                            </div>
                            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                            </svg>
                        </div>
                    </div>
                `;
                item.addEventListener('click', () => showAssetDetails(data));
                assetItems.appendChild(item);
            });

            // Set default header display to first asset
            const firstData = assetData[0];
            ownerNameDisplay.textContent = firstData.OwnerName;
            ownerInitials.textContent = firstData.OwnerName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase();
            timestampDisplay.textContent = `Last updated: ${firstData.Timestamp}`;
        }

        // Display asset details
        function showAssetDetails(data) {
            assetList.classList.add('hidden');
            assetDetail.classList.remove('hidden');
            listViewBtn.classList.remove('hidden');
            detailViewBtn.classList.remove('hidden');

            // Update header display for selected asset
            ownerNameDisplay.textContent = data.OwnerName;
            ownerInitials.textContent = data.OwnerName.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase();
            timestampDisplay.textContent = `Last updated: ${data.Timestamp}`;

            assetDetail.innerHTML = `
                <div class="space-y-6">
                    <!-- Asset Summary Card -->
                    <div class="bg-white rounded-xl shadow-sm p-6 card">
                        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
                            <div class="flex items-start space-x-4">
                                <div class="p-3 bg-indigo-100 rounded-lg">
                                    <svg class="w-5 h-5 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                    </svg>
                                </div>
                                <div>
                                    <h2 class="text-xl font-bold text-gray-900">${data.AssetInformation.Hostname}</h2>
                                    <p class="text-gray-600">${data.AssetInformation.Manufacturer} ${data.AssetInformation.Model}</p>
                                    <div class="mt-2 flex flex-wrap gap-2">
                                        <span class="px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full">${data.AssetInformation.AssetType}</span>
                                        <span class="px-2 py-1 bg-purple-100 text-purple-800 text-xs font-medium rounded-full">${data.AssetInformation.OS}</span>
                                        <span class="px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">Serial: ${data.AssetInformation.SerialNumber}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="mt-4 md:mt-0">
                                <div class="text-right">
                                    <p class="text-sm text-gray-500">Owner</p>
                                    <p class="font-medium text-gray-900">${data.OwnerName}</p>
                                </div>
                                <div class="mt-2 text-right">
                                    <p class="text-sm text-gray-500">Last User</p>
                                    <p class="font-medium text-gray-900">${data.AssetInformation.LastUser}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Detail Sections -->
                    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        <!-- Left Column -->
                        <div class="lg:col-span-2 space-y-6">
                            <!-- System Information -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"></path>
                                    </svg>
                                    System Information
                                </h3>
                                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div>
                                        <p class="text-sm text-gray-500">Operating System</p>
                                        <p class="font-medium">${data.AssetInformation.OS} ${data.AssetInformation.Version}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Build Number</p>
                                        <p class="font-medium">${data.AssetInformation.Build}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Processor</p>
                                        <p class="font-medium">${data.AssetInformation.Processor}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Graphics</p>
                                        <p class="font-medium">${data.AssetInformation.Graphics.join(', ')}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Motherboard</p>
                                        <p class="font-medium">${data.AssetInformation.Motherboard}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Security</p>
                                        <p class="font-medium">${data.AssetInformation.Antivirus}</p>
                                        <p class="font-medium">Firewall: ${data.AssetInformation.Firewall}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Audio</p>
                                        <p class="font-medium">${data.AssetInformation.Audio.join(', ')}</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Storage Information -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5z"></path>
                                    </svg>
                                    Storage Information
                                </h3>
                                
                                <h4 class="font-medium text-gray-700 mt-4 mb-2">Physical Disks</h4>
                                <div class="space-y-4">
                                    ${data.PhysicalDisks.map(d => `
                                    <div class="border border-gray-200 rounded-lg p-4">
                                        <div class="flex justify-between items-center mb-2">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5z"></path>
                                                </svg>
                                                <span class="font-medium">${d.Model}</span>
                                            </div>
                                            <span class="text-sm text-gray-500">${d.SizeGB} GB</span>
                                        </div>
                                        <div class="flex justify-between text-sm text-gray-500">
                                            <span>${d.MediaType}</span>
                                            <span>${d.BusType}</span>
                                            <span>${d.Status}</span>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                                
                                <h4 class="font-medium text-gray-700 mt-6 mb-2">Logical Drives</h4>
                                <div class="space-y-4">
                                    ${data.LogicalDrives.map(d => `
                                    <div class="border border-gray-200 rounded-lg p-4">
                                        <div class="flex justify-between items-center mb-2">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2"></path>
                                                </svg>
                                                <span class="font-medium">Drive ${d.DriveLetter}: ${d.VolumeLabel}</span>
                                            </div>
                                            <span class="text-sm font-medium">${d.UsedSpaceGB} GB / ${d.TotalSizeGB} GB</span>
                                        </div>
                                        <div class="progress-bar mt-2">
                                            <div class="progress-fill" style="width: ${d.UsedPercent}%"></div>
                                        </div>
                                        <div class="flex justify-between text-sm text-gray-500 mt-2">
                                            <span>${d.FileSystem}</span>
                                            <span>${d.FreeSpaceGB} GB free (${100 - d.UsedPercent}%)</span>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                            </div>

                            <!-- Network Interfaces -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                    </svg>
                                    Network Interfaces
                                </h3>
                                <div class="space-y-4">
                                    ${data.NetworkInterfaces.map(ni => `
                                    <div class="border border-gray-200 rounded-lg p-4">
                                        <div class="flex justify-between items-center mb-2">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                                                </svg>
                                                <span class="font-medium">${ni.Name}</span>
                                            </div>
                                            <span class="status-badge ${ni.Status === 'Up' ? 'status-up' : 'status-disconnected'}">${ni.Status}</span>
                                        </div>
                                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
                                            <div>
                                                <p class="text-sm text-gray-500">IPv4 Address</p>
                                                <p class="font-medium">${ni.IPv4 || 'N/A'}</p>
                                            </div>
                                            <div>
                                                <p class="text-sm text-gray-500">MAC Address</p>
                                                <p class="font-medium">${ni.MAC}</p>
                                            </div>
                                            <div>
                                                <p class="text-sm text-gray-500">Vendor</p>
                                                <p class="font-medium">${ni.Vendor}</p>
                                            </div>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                            </div>

                            <!-- Installed Software -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2"></path>
                                    </svg>
                                    Installed Software
                                </h3>
                                <div class="space-y-4">
                                    ${data.InstalledSoftware.map(s => `
                                    <div class="border border-gray-200 rounded-sm p-3">
                                        <div class="flex justify-between items-center mb-2">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2"></path>
                                                </svg>
                                                <span class="font-medium">${s.Name}</span>
                                            </div>
                                            <span class="text-sm text-gray-500">${s.Version}</span>
                                        </div>
                                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                                            <div>
                                                <p class="text-gray-500">Publisher</p>
                                                <p>${s.Publisher || 'N/A'}</p>
                                            </div>
                                            <div>
                                                <p class="text-sm text-gray-500">Install Date</p>
                                                <p>${s.InstallDate || 'N/A'}</p>
                                            </div>
                                            <div>
                                                <p class="text-gray-500">Scope</p>
                                                <p>${s.Scope}</p>
                                            </div>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                            </div>
                        </div>

                        <!-- Right Column -->
                        <div class="space-y-6">
                            <!-- Memory Information -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 27">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                    </svg>
                                    Memory
                                </h3>
                                <div class="mb-4">
                                    <div class="flex justify-between items-center mb-1">
                                        <span class="text-sm font-medium text-gray-700">Total Memory</span>
                                        <span class="text-sm font-medium">${data.MemoryInformation.TotalMemoryGB} GB</span>
                                    </div>
                                    <div class="w-full bg-gray-200 rounded-full h-2.5">
                                        <div class="bg-indigo-600 h-2.5 rounded-full" style="width: 100%"></div>
                                    </div>
                                </div>
                                
                                <h4 class="font-medium text-gray-700 mt-4 mb-2">Modules</h4>
                                <div class="space-y-3">
                                    ${data.MemoryInformation.Modules.map(m => `
                                    <div class="border border-gray-200 rounded-lg p-3">
                                        <div class="flex justify-between items-center">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                                </svg>
                                                <span class="font-medium">${m.Manufacturer}</span>
                                            </div>
                                            <span class="text-sm font-medium">${m.CapacityGB} GB</span>
                                        </div>
                                        <div class="flex justify-between text-xs text-gray-500 mt-1">
                                            <span>${m.RAMType} @ ${m.SpeedMHz} MHz</span>
                                            <span>${m.PartNumber}</span>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                            </div>

                            <!-- Battery Information -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                    </svg>
                                    Battery
                                </h3>
                                <div class="space-y-3">
                                    <div>
                                        <p class="text-sm text-gray-500">Model</p>
                                        <p class="font-medium">${data.BatteryInformation.Model}</p>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Health</p>
                                        <div class="flex items-center space-x-2">
                                            <div class="w-full bg-gray-200 rounded-full h-2.5">
                                                <div class="${data.BatteryInformation.BatteryHealthPercent >= 80 ? 'bg-green-600' : data.BatteryInformation.BatteryHealthPercent >= 60 ? 'bg-amber-600' : 'bg-red-600'} h-2.5 rounded-full" style="width: ${data.BatteryInformation.BatteryHealthPercent}%"></div>
                                            </div>
                                            <span class="text-sm font-medium">${data.BatteryInformation.BatteryHealthPercent}% health</span>
                                        </div>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Charge Remaining</p>
                                        <div class="flex items-center space-x-2">
                                            <div class="w-full bg-gray-200 rounded-full h-2.5">
                                                <div class="bg-green-600 h-2.5 rounded-full" style="width: ${data.BatteryInformation.EstimatedChargeRemainingPercent}%"></div>
                                            </div>
                                            <span class="text-sm font-medium">${data.BatteryInformation.EstimatedChargeRemainingPercent}%</span>
                                        </div>
                                    </div>
                                    <div class="grid grid-cols-2 gap-4">
                                        <div>
                                            <p class="text-sm text-gray-500">Designed Capacity</p>
                                            <p class="font-medium">${data.BatteryInformation.DesignedCapacityWh} Wh</p>
                                        </div>
                                        <div>
                                            <p class="text-sm text-gray-500">Full Charged Capacity</p>
                                            <p class="font-medium">${data.BatteryInformation.FullChargedCapacityWh} Wh</p>
                                        </div>
                                    </div>
                                    <div>
                                        <p class="text-sm text-gray-500">Cycle Count</p>
                                        <p class="font-medium">${data.BatteryInformation.CycleCount}</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Monitors -->
                            <div class="bg-white rounded-xl shadow-sm p-6 card">
                                <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                                    <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"></path>
                                    </svg>
                                    Monitors
                                </h3>
                                <div class="space-y-4">
                                    ${data.MonitorInformation.map(m => `
                                    <div class="border border-gray-200 rounded-lg p-4">
                                        <div class="flex justify-between items-center mb-2">
                                            <div class="flex items-center">
                                                <svg class="w-4 h-4 text-indigo-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"></path>
                                                </svg>
                                                <span class="font-medium">${m.Manufacturer}</span>
                                            </div>
                                            <span class="text-sm text-gray-500">${m.ScreenSizeInch}"</span>
                                        </div>
                                        <div class="grid grid-cols-2 gap-2 text-sm">
                                            <div>
                                                <p class="text-gray-500">Resolution</p>
                                                <p>${m.NativeResolution}</p>
                                            </div>
                                            <div>
                                                <p class="text-gray-500">Year</p>
                                                <p>${m.YearOfManufacture}</p>
                                            </div>
                                            <div>
                                                <p class="text-gray-500">Model</p>
                                                <p>${m.FriendlyName}</p>
                                            </div>
                                            <div>
                                                <p class="text-sm text-gray-500">Serial</p>
                                                <p>${m.SerialNumber}</p>
                                            </div>
                                        </div>
                                    </div>
                                    `).join('')}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        }

        // Navigation event listeners
        listViewBtn.addEventListener('click', showAssetList);
        detailViewBtn.addEventListener('click', showAssetList);

        // Sync data button event listener
        syncDataBtn.addEventListener('click', async () => {
            syncDataBtn.disabled = true;
            syncDataBtn.innerHTML = `
                <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.582m0 0a8.001 8.001 0 01-15.356-2m15.356 2H15"></path>
                </svg>
                <span>Syncing...</span>
            `;
            await loadAndDisplayAssets();
            syncDataBtn.disabled = false;
            syncDataBtn.innerHTML = `
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.582m0 0a8.001 8.001 0 01-15.356-2m15.356 2H15"></path>
                </svg>
                <span>Sync Data</span>
            `;
        });

        // Initial load
        await loadAndDisplayAssets();
    }

    // Initialize the app
    await loadAndDisplayAssets();
}

// Initialize the app
initializeApp();