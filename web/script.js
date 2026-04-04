const ResourceName = 'mri_Qfarm';

const Pages = {
    SELECTOR: 'farm-selector',
    CREATOR: 'farm-creator'
};

let currentFarmData = null;
let currentTab = 'general';

$(document).ready(() => {
    $('#modal-container').hide();

    $('#close-nui').click(() => {
        $.post(`https://${ResourceName}/close`, JSON.stringify({}));
    });

    // Tab Switching in Creator
    $(document).on('click', '.nav-item', function() {
        if (!currentFarmData || currentFarmData.selectedIdx === undefined) return;
        const tab = $(this).data('tab');
        $('.nav-item').removeClass('active');
        $(this).addClass('active');
        switchTab(tab);
    });

    // Back to Route Selection
    $(document).on('click', '#back-to-routes', () => {
        showCreator(currentFarmData.farms, currentFarmData.config);
    });

    $('#create-new-farm-btn').click(() => createNewFarm());

    // Message Listener
    window.addEventListener('message', (event) => {
        const data = event.data;

        if (data.action === 'open') {
            $('#app').fadeIn(300);
            if (data.type === 'selector') {
                showSelector(data.farms);
            } else if (data.type === 'creator') {
                showCreator(data.farms, data.config);
                
                // State Persistence: Auto-select farm and tab if target is provided
                if (data.targetFarmId !== undefined && data.targetFarmId !== null) {
                    const idx = data.farms.findIndex(f => f.farmId == data.targetFarmId);
                    if (idx !== -1) {
                        selectRoute(idx, data.targetTab || 'general', data.targetItemKey);
                    }
                }
            }
        } else if (data.action === 'close') {
            $('#app').fadeOut(300);
        }
    });
});

function switchTab(tab) {
    currentTab = tab;
    renderCreatorContent();
    updateClientEditorState();
}

function showSelector(farms) {
    $('.page').hide();
    $(`#${Pages.SELECTOR}`).show();
    
    const $list = $('#farm-list');
    const $cancelContainer = $('#cancel-container');
    $list.empty();
    $cancelContainer.empty();

    farms.forEach(farm => {
        if (farm.isCancel) {
            const $cancelBtn = $(`
                <button class="btn btn-danger" style="width: 100%; max-width: 400px; padding: 16px; text-transform: uppercase;">
                    <i class="fa-solid fa-ban"></i> Cancelar Rota Atual
                </button>
            `);

            $cancelBtn.click(() => {
                $.post(`https://${ResourceName}/selectFarm`, JSON.stringify({ isCancel: true }));
            });

            $cancelContainer.append($cancelBtn);
        } else {
            const $card = $(`
                <div class="farm-card">
                    <i class="fa-solid fa-tractor main-icon"></i>
                    <h2>${farm.name}</h2>
                    <p>${farm.description || 'Trabalho de colheita e processamento.'}</p>
                    <button class="btn btn-primary" style="margin-top: auto; width: 100%;">SELECIONAR</button>
                </div>
            `);

            $card.click(() => {
                $.post(`https://${ResourceName}/selectFarm`, JSON.stringify({ farmId: farm.id }));
            });

            $list.append($card);
        }
    });
}

function showCreator(farms, config) {
    $('.page').hide();
    $(`#${Pages.CREATOR}`).show();
    $('#creator-route-view').show();
    $('#creator-editor-view').hide();
    $('.top-nav').hide();

    currentFarmData = { farms: farms, config: config };
    
    const $list = $('#creator-route-list');
    $list.empty();

    farms.forEach((farm, i) => {
        const $card = $(`
            <div class="farm-card">
                <i class="fa-solid fa-route main-icon"></i>
                <h2>${farm.name}</h2>
                <div style="display: flex; gap: 8px; margin-top: auto; width: 100%;">
                    <button class="btn btn-primary" style="flex: 2;">EDITAR</button>
                    <button class="btn btn-secondary" onclick="event.stopPropagation(); duplicateFarm(${i})" title="Duplicar"><i class="fa-solid fa-copy"></i></button>
                </div>
            </div>
        `);

        $card.find('.btn-primary').click(() => selectRoute(i));
        $list.append($card);
    });
}

function selectRoute(idx, tab = 'general', itemKey = null) {
    currentFarmData.selectedIdx = idx;
    $('#creator-route-view').hide();
    $('#creator-editor-view').show();
    $('.top-nav').show();
    
    // Reset tabs
    $('.nav-item').removeClass('active');
    $(`.nav-item[data-tab="${tab}"]`).addClass('active');
    
    currentTab = tab;
    
    // If we have a target item, we need to ensure the renderCreatorContent uses it
    if (tab === 'points' && itemKey) {
        // We'll handle this in renderCreatorContent by checking a temporary property
        currentFarmData.targetItemKey = itemKey;
    }

    renderCreatorContent();
    updateClientEditorState();
}

function renderCreatorContent() {
    const $panel = $('#tab-content');
    $panel.empty();

    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    if (!farm) return;

    if (currentTab === 'general') {
        $panel.append(`
            <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 32px;">
                <button class="btn btn-secondary" id="back-to-routes"><i class="fa-solid fa-arrow-left"></i> VOLTAR</button>
                <h3 style="font-size: 1.25rem; font-weight: 700;">Configuração: ${farm.name}</h3>
            </div>
            
            <div class="form-group">
                <label>Nome do Farm</label>
                <input type="text" id="edit-farm-name" value="${farm.name}">
            </div>
            
            <div class="form-group" style="margin-top: 24px;">
                <label>Posição de Início (Onde puxa a rota)</label>
                <div style="display: flex; align-items: center; justify-content: space-between; background: var(--surface-secondary); padding: 12px 16px; border-radius: 8px; margin-bottom: 8px;">
                    <span style="font-size: 0.85rem; color: var(--text-secondary);">
                        <i class="fa-solid fa-location-dot" style="margin-right: 8px; color: var(--accent-primary);"></i>
                        ${farm.config.start.location ? 'Local Definido' : 'Local não definido'}
                    </span>
                    <div style="display: flex; gap: 4px;">
                        <button class="btn btn-secondary btn-sm" onclick="setStartLocation()" title="Definir"><i class="fa-solid fa-map-pin"></i></button>
                        ${farm.config.start.location ? `<button class="btn btn-secondary btn-sm" onclick="tpStart()" title="Teleportar"><i class="fa-solid fa-location-arrow"></i></button>` : ''}
                    </div>
                </div>

                <div style="background: var(--surface-card); padding: 12px; border: 1px solid var(--border-default); border-radius: 8px; margin-top: 12px;">
                    <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 8px;">
                        <input type="checkbox" id="ped-enabled" style="width: 16px; height: 16px;" ${farm.config.start.ped?.enabled ? 'checked' : ''} onchange="togglePedSettings()">
                        <label style="margin-bottom: 0; cursor: pointer;" for="ped-enabled">Habilitar NPC no Início</label>
                    </div>
                    <div id="ped-settings-container" style="display: ${farm.config.start.ped?.enabled ? 'block' : 'none'}; border-top: 1px solid var(--border-subtle); padding-top: 10px;">
                        <label style="font-size: 9px;">Modelo do Ped</label>
                        <input type="text" id="ped-model" value="${farm.config.start.ped?.model || 's_m_m_scientist_01'}" style="margin-bottom: 8px;">
                        <button class="btn btn-secondary btn-sm" style="width: 100%; font-size: 0.75rem;" onclick="capturePedData()">
                            <i class="fa-solid fa-camera"></i> CAPTURAR MINHA POSIÇÃO + HEADING
                        </button>
                        <div style="margin-top: 6px; font-size: 0.7rem; color: var(--text-muted);">
                            ${farm.config.start.ped?.coords ? 'Status: <span style="color: var(--status-success)">Posição Salva</span>' : 'Status: <span style="color: var(--status-warning)">Aguardando Captura</span>'}
                        </div>
                    </div>
                </div>
            </div>

            <div style="display: flex; gap: 12px; margin-top: 32px;">
                <button class="btn btn-primary" id="save-general-btn" onclick="saveGeneral()" style="flex: 1;">SALVAR ALTERAÇÕES</button>
                <button class="btn btn-danger" onclick="deleteFarmConfirm()" style="flex: 1;">EXCLUIR FARM</button>
            </div>
        `);
    } else if (currentTab === 'items') {
        const items = Object.entries(farm.config.items);

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px;">
                <h3 style="font-size: 1.25rem; font-weight: 700;">Itens da Rota</h3>
                <button class="btn btn-primary" onclick="addFarmItem()"><i class="fa-solid fa-plus"></i> ADICIONAR ITEM</button>
            </div>
            <div class="item-list">
                ${items.map(([key, val]) => `
                    <div class="farm-card" style="flex-direction: row; justify-content: space-between; padding: 16px 24px; align-items: center; margin-bottom: 12px; min-height: auto;">
                        <div style="z-index: 1;">
                            <span class="data-value" style="font-size: 1.1rem;">${val.customName || key}</span><br>
                            <span class="data-label">${key}</span>
                        </div>
                        <div style="display: flex; gap: 8px; z-index: 1;">
                            <button class="btn btn-secondary" onclick="editItem('${key}')" title="Configurações"><i class="fa-solid fa-gear"></i></button>
                            <button class="btn btn-danger" style="padding: 0 12px;" onclick="removeItemConfirm('${key}')" title="Remover"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${items.length === 0 ? '<p style="color: var(--text-muted);">Nenhum item configurado. Clique em ADICIONAR para começar.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'points') {
        const items = Object.keys(farm.config.items);
        let selectedItem = currentFarmData.targetItemKey || $('#point-item-selector').val() || items[0];
        
        // Clean up the target once used or if it's invalid
        if (currentFarmData.targetItemKey) {
            delete currentFarmData.targetItemKey;
        }

        const points = selectedItem ? (farm.config.items[selectedItem].points || []) : [];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px;">
                <h3 style="font-size: 1.25rem; font-weight: 700;">Pontos de Coleta</h3>
                <button class="btn btn-primary" onclick="addFarmPoint()"><i class="fa-solid fa-location-dot"></i> ADICIONAR PONTOS</button>
            </div>

            <div class="form-group" style="margin-bottom: 24px;">
                <label>Ver pontos para o item:</label>
                <select id="point-item-selector" onchange="renderCreatorContent()">
                    ${items.map(k => `<option value="${k}" ${k === selectedItem ? 'selected' : ''}>${farm.config.items[k].customName || k}</option>`).join('')}
                </select>
                ${items.length === 0 ? '<p style="color: var(--status-error); font-size: 0.8rem; margin-top: 8px;">Adicione itens antes de configurar pontos!</p>' : ''}
            </div>

            <div class="point-list">
                ${points.map((p, i) => `
                    <div class="farm-card" style="flex-direction: row; justify-content: space-between; padding: 16px 24px; align-items: center; margin-bottom: 12px; min-height: auto;">
                        <div style="z-index: 1;">
                            <span class="data-label">Ponto #${i + 1}</span><br>
                            <span class="data-value" style="font-size: 0.9rem;">${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}</span>
                        </div>
                        <div style="display: flex; gap: 8px; z-index: 1;">
                            <button class="btn btn-secondary" onclick="tpToPoint('${selectedItem}', ${i})" title="Teleportar"><i class="fa-solid fa-location-crosshairs"></i></button>
                            <button class="btn btn-secondary" onclick="updatePoint('${selectedItem}', ${i})" title="Definir aqui"><i class="fa-solid fa-location-dot"></i></button>
                            <button class="btn btn-danger" style="padding: 0 12px;" onclick="removePointConfirm('${selectedItem}', ${i})" title="Remover"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${selectedItem && points.length === 0 ? '<p style="color: var(--text-muted);">Nenhum ponto registrado para este item.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'groups') {
        const groups = farm.group.name || [];
        const grade = farm.group.grade || 0;

        $panel.append(`
            <h3 style="font-size: 1.25rem; font-weight: 700; margin-bottom:32px;">Controle de Acesso</h3>
            
            <div class="form-group">
                <label>Grupos Permitidos (Jobs/Gangs)</label>
                <div style="margin-bottom: 12px; color: var(--text-secondary); font-size: 0.9rem;">
                    Atual: <span class="data-value">${Array.isArray(groups) && groups.length > 0 ? groups.join(', ') : 'Público'}</span>
                </div>
                <button class="btn btn-secondary" onclick="editGroups()"><i class="fa-solid fa-users-gear"></i> EDITAR GRUPOS</button>
            </div>

            <div class="form-group">
                <label>Grade/Rank Mínimo</label>
                <input type="number" id="edit-farm-grade" value="${grade}" onchange="saveGrade()">
            </div>
        `);
    }
}

// Logic Actions
function createNewFarm() {
    openModal('Novo Farm', `
        <div class="form-group">
            <label>Nome do Novo Farm</label>
            <input type="text" id="new-farm-name" placeholder="Ex: Farm de Cocaína">
        </div>
    `, () => {
        const name = $('#new-farm-name').val();
        if (name) {
            $.post(`https://${ResourceName}/createFarm`, JSON.stringify({ name }));
            return true;
        }
        return false;
    });
}

function duplicateFarm(idx) {
    const farm = currentFarmData.farms[idx];
    openModal('Duplicar Rota', `
        <p>Deseja duplicar a rota <strong>${farm.name}</strong>?</p>
        <div class="form-group" style="margin-top: 20px;">
            <label>Nome da Nova Rota</label>
            <input type="text" id="dup-farm-name" value="${farm.name} (Cópia)">
        </div>
    `, () => {
        const newName = $('#dup-farm-name').val();
        if (newName) {
            $.post(`https://${ResourceName}/duplicateFarm`, JSON.stringify({ 
                farmKey: farm.id,
                newName: newName 
            }));
            return true;
        }
        return false;
    });
}

function refreshFarms() {
    $.post(`https://${ResourceName}/refreshFarms`, JSON.stringify({}));
}

function saveGeneral() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const name = $('#edit-farm-name').val();
    const $btn = $('#save-general-btn');
    const originalText = $btn.html();

    const pedConfig = {
        enabled: $('#ped-enabled').is(':checked'),
        model: $('#ped-model').val()
    };

    $.post(`https://${ResourceName}/saveGeneral`, JSON.stringify({ 
        farmKey: farm.id,
        name: name,
        ped: pedConfig
    }));

    $btn.addClass('btn-success').removeClass('btn-primary').html('<i class="fa-solid fa-check"></i> SALVO!');
    setTimeout(() => {
        $btn.removeClass('btn-success').addClass('btn-primary').html(originalText);
    }, 2000);
}

function tpStart() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/tpStart`, JSON.stringify({ farmKey: farm.id }));
}

function togglePedSettings() {
    const enabled = $('#ped-enabled').is(':checked');
    $('#ped-settings-container').toggle(enabled);
}

function capturePedData() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const model = $('#ped-model').val();
    $.post(`https://${ResourceName}/capturePedData`, JSON.stringify({ farmKey: farm.id, model: model }));
    $('#app').fadeOut(200);
}

function setStartLocation() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/setStartLocation`, JSON.stringify({ farmKey: farm.id }));
    $('#app').fadeOut(200);
}

function updateClientEditorState() {
    if (!currentFarmData || currentFarmData.selectedIdx === undefined) return;
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const items = Object.keys(farm.config.items);
    const selectedItem = $('#point-item-selector').val() || items[0];
    
    $.post(`https://${ResourceName}/updateEditorState`, JSON.stringify({
        farmKey: farm.id,
        itemKey: selectedItem
    }));
}

function deleteFarmConfirm() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    
    openModal('Excluir Farm', `
        <p>Tem certeza que deseja excluir o farm <strong>${farm.name}</strong>?</p>
        <p style="color: var(--status-error); font-size: 0.8rem; margin-top: 8px;">Esta ação não pode ser desfeita.</p>
    `, () => {
        $.post(`https://${ResourceName}/deleteFarm`, JSON.stringify({ farmKey: farm.id }));
        return true;
    });
}

function addFarmItem() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/addFarmItem`, JSON.stringify({ farmKey: farm.id }));
    $('#app').fadeOut(200);
}

function editItem(itemKey) {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const item = farm.config.items[itemKey];

    openModal(`Configurar: ${itemKey}`, `
        <div class="form-group">
            <label>Nome Personalizado</label>
            <input type="text" id="item-custom-name" value="${item.customName || ''}">
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
            <div class="form-group">
                <label>Qtd Mínima</label>
                <input type="number" id="item-min" value="${item.min || 1}">
            </div>
            <div class="form-group">
                <label>Qtd Máxima</label>
                <input type="number" id="item-max" value="${item.max || 1}">
            </div>
        </div>
        <div class="form-group">
            <label>Tempo de Coleta (ms)</label>
            <input type="number" id="item-time" value="${item.collectTime || 2000}">
        </div>
    `, () => {
        $.post(`https://${ResourceName}/saveItemConfig`, JSON.stringify({
            farmKey: farm.id,
            itemKey: itemKey,
            config: {
                customName: $('#item-custom-name').val(),
                min: parseInt($('#item-min').val()),
                max: parseInt($('#item-max').val()),
                collectTime: parseInt($('#item-time').val())
            }
        }));
        return true;
    });
}

function removeItemConfirm(itemKey) {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    openModal('Remover Item', `<p>Deseja remover o item <strong>${itemKey}</strong> desta rota?</p>`, () => {
        $.post(`https://${ResourceName}/removeItem`, JSON.stringify({ farmKey: farm.id, itemKey: itemKey }));
        return true;
    });
}

function addFarmPoint() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const selectedItem = $('#point-item-selector').val();
    
    if (!selectedItem) {
        openModal('Erro', '<p>Adicione um item antes de marcar pontos!</p>', () => true);
        return;
    }

    $.post(`https://${ResourceName}/addPoint`, JSON.stringify({
        farmKey: farm.id,
        itemKey: selectedItem
    }));
    $('#app').fadeOut(200);
}

function removePointConfirm(itemKey, pointIdx) {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    openModal('Remover Ponto', `<p>Deseja remover este ponto de coleta?</p>`, () => {
        $.post(`https://${ResourceName}/removePoint`, JSON.stringify({
            farmKey: farm.id,
            itemKey: itemKey,
            pointIdx: pointIdx
        }));
        return true;
    });
}

function tpToPoint(itemKey, idx) {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/tpPoint`, JSON.stringify({
        farmKey: farm.id,
        itemKey: itemKey,
        pointIdx: idx
    }));
}

function updatePoint(itemKey, idx) {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/updatePoint`, JSON.stringify({
        farmKey: farm.id,
        itemKey: itemKey,
        pointIdx: idx
    }));
    $('#app').fadeOut(200);
}

function saveGrade() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    const grade = $('#edit-farm-grade').val();
    $.post(`https://${ResourceName}/saveGrade`, JSON.stringify({ farmKey: farm.id, grade: grade }));
}

function editGroups() {
    const farm = currentFarmData.farms[currentFarmData.selectedIdx];
    $.post(`https://${ResourceName}/editGroups`, JSON.stringify({ farmKey: farm.id }));
    $('#app').fadeOut(200);
}

function openModal(title, bodyHtml, onConfirm) {
    $('#modal-title').text(title);
    $('#modal-body').html(bodyHtml);
    $('#modal-container').fadeIn(200);

    $('#modal-confirm').off('click').on('click', () => {
        if (onConfirm()) {
            $('#modal-container').fadeOut(200);
        }
    });

    $('#modal-cancel').off('click').on('click', () => {
        $('#modal-container').fadeOut(200);
    });
}
