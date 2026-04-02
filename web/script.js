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
        const tab = $(this).data('tab');
        $('.nav-item').removeClass('active');
        $(this).addClass('active');
        switchTab(tab);
    });

    // Message Listener
    window.addEventListener('message', (event) => {
        const data = event.data;

        if (data.action === 'open') {
            $('#app').fadeIn(300);
            if (data.type === 'selector') {
                showSelector(data.farms);
            } else if (data.type === 'creator') {
                showCreator(data.farms, data.config);
            }
        } else if (data.action === 'close') {
            $('#app').fadeOut(300);
        }
    });
});

function switchTab(tab) {
    currentTab = tab;
    renderCreatorContent();
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
    currentFarmData = farms;
    // Reset tabs
    $('.nav-item').removeClass('active');
    $('.nav-item[data-tab="general"]').addClass('active');
    switchTab('general');
}

function renderCreatorContent() {
    const $panel = $('#creator-panel');
    $panel.empty();

    const selectedIdx = $('#creator-select-farm').val() || 0;
    const currentFarm = currentFarmData[selectedIdx];

    if (currentTab === 'general') {
        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px;">
                <h3 style="font-size: 1.25rem; font-weight: 700;">Configuração Geral</h3>
                <div style="display: flex; gap: 10px;">
                    <button class="btn btn-success" onclick="createNewFarm()"><i class="fa-solid fa-plus"></i> NOVO</button>
                    ${currentFarm ? `<button class="btn btn-secondary" onclick="duplicateFarm(${selectedIdx})"><i class="fa-solid fa-copy"></i> DUPLICAR</button>` : ''}
                </div>
            </div>
            
            <div class="form-group">
                <label>Selecionar Farm para Edição</label>
                <select id="creator-select-farm" onchange="renderCreatorContent()">
                    ${currentFarmData.map((f, i) => `<option value="${i}" ${i == selectedIdx ? 'selected' : ''}>${f.name}</option>`).join('')}
                </select>
            </div>

            ${currentFarm ? `
                <div class="form-group">
                    <label>Nome do Farm</label>
                    <input type="text" id="edit-farm-name" value="${currentFarm.name}">
                </div>
                
                <div style="display: flex; gap: 12px; margin-top: 32px;">
                    <button class="btn btn-primary" onclick="saveGeneral()">SALVAR ALTERAÇÕES</button>
                    <button class="btn btn-danger" onclick="deleteFarmConfirm()">EXCLUIR FARM</button>
                </div>
            ` : '<p style="color: var(--text-muted);">Nenhum farm encontrado. Crie um novo no botão superior.</p>'}
        `);
    } else if (currentTab === 'items') {
        const items = currentFarm ? Object.entries(currentFarm.config.items) : [];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px;">
                <h3 style="font-size: 1.25rem; font-weight: 700;">Itens do Farm</h3>
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
                            <button class="btn btn-secondary" onclick="editItem('${key}')" title="Editar"><i class="fa-solid fa-pen"></i></button>
                            <button class="btn btn-danger" style="padding: 0 12px;" onclick="removeItem('${key}')" title="Remover"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${items.length === 0 ? '<p style="color: var(--text-muted);">Nenhum item configurado para este farm.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'points') {
        const firstItemKey = currentFarm ? Object.keys(currentFarm.config.items)[0] : null;
        const farmPoints = firstItemKey ? currentFarm.config.items[firstItemKey].points || [] : [];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px;">
                <h3 style="font-size: 1.25rem; font-weight: 700;">Pontos de Farm</h3>
                <button class="btn btn-primary" onclick="addFarmPoint()"><i class="fa-solid fa-location-dot"></i> ADICIONAR PONTO</button>
            </div>
            <p style="margin-bottom: 20px; color: var(--text-secondary); font-size: 0.9rem;">Configure os pontos para: <span class="data-value">${firstItemKey || 'Nenhum item'}</span></p>
            <div class="point-list">
                ${farmPoints.map((p, i) => `
                    <div class="farm-card" style="flex-direction: row; justify-content: space-between; padding: 16px 24px; align-items: center; margin-bottom: 12px; min-height: auto;">
                        <div style="z-index: 1;">
                            <span class="data-label">Ponto #${i + 1}</span><br>
                            <span class="data-value" style="font-size: 0.9rem;">${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}</span>
                        </div>
                        <div style="display: flex; gap: 8px; z-index: 1;">
                            <button class="btn btn-secondary" onclick="tpToPoint(${i})"><i class="fa-solid fa-location-crosshairs"></i> TP</button>
                            <button class="btn btn-danger" style="padding: 0 12px;" onclick="removePoint(${i})"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${farmPoints.length === 0 ? '<p style="color: var(--text-muted);">Adicione itens primeiro para começar a marcar pontos.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'groups') {
        const groups = currentFarm ? currentFarm.group.name || [] : [];
        const grade = currentFarm ? currentFarm.group.grade || 0 : 0;

        $panel.append(`
            <h3 style="font-size: 1.25rem; font-weight: 700; margin-bottom:32px;">Controle de Acesso</h3>
            
            <div class="form-group">
                <label>Grupos Permitidos (Jobs/Gangs)</label>
                <div style="margin-bottom: 12px; color: var(--text-secondary); font-size: 0.9rem;">
                    Atual: <span class="data-value">${Array.isArray(groups) ? groups.join(', ') : (groups || 'Público')}</span>
                </div>
                <button class="btn btn-secondary" onclick="editGroups()"><i class="fa-solid fa-users-gear"></i> EDITAR GRUPOS</button>
            </div>

            <div class="form-group">
                <label>Grade/Rank Mínimo</label>
                <input type="number" id="edit-farm-grade" value="${grade}" onchange="saveGrade()">
            </div>
            
            <div class="info-card" style="background: var(--accent-subtle); padding: 16px; border-radius: 8px; border-left: 4px solid var(--accent-primary); margin-top: 32px;">
                <p style="font-size: 0.85rem; color: var(--text-secondary);">
                    <i class="fa-solid fa-circle-info" style="color: var(--accent-primary); margin-right: 8px;"></i>
                    As rotas globais permitem que múltiplos grupos acessem o mesmo farm. Deixe o campo de grupos vazio para tornar a rota <strong>pública</strong>.
                </p>
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
    const farm = currentFarmData[idx];
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

function saveGeneral() {
    const selectedIdx = $('#creator-select-farm').val();
    const name = $('#edit-farm-name').val();
    const farm = currentFarmData[selectedIdx];
    
    $.post(`https://${ResourceName}/saveGeneral`, JSON.stringify({ 
        farmKey: farm.id,
        name: name 
    }));
}

function deleteFarmConfirm() {
    const selectedIdx = $('#creator-select-farm').val();
    const farm = currentFarmData[selectedIdx];
    
    openModal('Excluir Farm', `
        <p>Tem certeza que deseja excluir o farm <strong>${farm.name}</strong>?</p>
        <p style="color: var(--status-error); font-size: 0.8rem; margin-top: 8px;">Esta ação não pode ser desfeita.</p>
    `, () => {
        $.post(`https://${ResourceName}/deleteFarm`, JSON.stringify({ farmKey: farm.id }));
        return true;
    });
}

function addFarmPoint() {
    const selectedIdx = $('#creator-select-farm').val();
    const currentFarm = currentFarmData[selectedIdx];
    const firstItem = Object.keys(currentFarm.config.items)[0];
    
    if (!firstItem) {
        openModal('Aviso', '<p>Adicione pelo menos um item na aba ITENS antes de marcar pontos!</p>', () => true);
        return;
    }

    $.post(`https://${ResourceName}/addPoint`, JSON.stringify({
        farmKey: currentFarm.id,
        itemKey: firstItem
    }));
    $('#app').fadeOut(200);
}

function saveGrade() {
    const selectedIdx = $('#creator-select-farm').val();
    const grade = $('#edit-farm-grade').val();
    const farm = currentFarmData[selectedIdx];
    
    $.post(`https://${ResourceName}/saveGrade`, JSON.stringify({ 
        farmKey: farm.id,
        grade: grade 
    }));
}

function editGroups() {
    const selectedIdx = $('#creator-select-farm').val();
    const farm = currentFarmData[selectedIdx];
    
    $.post(`https://${ResourceName}/editGroups`, JSON.stringify({ 
        farmKey: farm.id 
    }));
    // Since complex multi-select is easier in Lua ox_lib, we use a callback to ox_lib
    $('#app').fadeOut(200);
}

function tpToPoint(idx) {
    const selectedIdx = $('#creator-select-farm').val();
    const currentFarm = currentFarmData[selectedIdx];
    const firstItem = Object.keys(currentFarm.config.items)[0];

    $.post(`https://${ResourceName}/tpPoint`, JSON.stringify({
        farmKey: currentFarm.id,
        itemKey: firstItem,
        pointIdx: idx
    }));
}

// Modal System logic
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
