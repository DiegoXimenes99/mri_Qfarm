const ResourceName = 'mri_Qfarm';

const Pages = {
    SELECTOR: 'farm-selector',
    CREATOR: 'farm-creator'
};

let currentFarmData = null;
let currentTab = 'general';

$(document).ready(() => {
    // Hide modal container on load (safety)
    $('#modal-container').hide();

    // Close NUI
    $('#close-nui').click(() => {
        $.post(`https://${ResourceName}/close`, JSON.stringify({}));
    });

    // Tab Switching in Creator
    $('.nav-item').click(function() {
        const tab = $(this).data('tab');
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
    $('.nav-item').removeClass('active');
    $(`.nav-item[data-tab="${tab}"]`).addClass('active');
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
                <button class="btn btn-danger" style="width: 80%; padding: 15px; font-size: 1.1rem; text-transform: uppercase; letter-spacing: 1px;">
                    <i class="fa-solid fa-ban" style="margin-right: 10px;"></i> Cancelar Rota Atual
                </button>
            `);

            $cancelBtn.click(() => {
                $.post(`https://${ResourceName}/selectFarm`, JSON.stringify({ isCancel: true }));
            });

            $cancelContainer.append($cancelBtn);
        } else {
            const $card = $(`
                <div class="farm-card">
                    <i class="fa-solid fa-tractor"></i>
                    <h2>${farm.name}</h2>
                    <p>${farm.description || 'Trabalho de colheita e processamento.'}</p>
                    <button class="btn btn-primary" style="margin-top: auto; width: 100%;">Selecionar</button>
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
    switchTab('general');
}

function renderCreatorContent() {
    const $panel = $('#creator-panel');
    $panel.empty();

    if (currentTab === 'general') {
        const selectedIdx = $('#creator-select-farm').val() || 0;
        const currentFarm = currentFarmData[selectedIdx];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3>Configuração Geral</h3>
                <button class="btn btn-primary" onclick="createNewFarm()">+ Novo Farm</button>
            </div>
            <div class="form-group">
                <label>Selecione o Farm para Editar</label>
                <select id="creator-select-farm" onchange="renderCreatorContent()">
                    ${currentFarmData.map((f, i) => `<option value="${i}" ${i == selectedIdx ? 'selected' : ''}>${f.name}</option>`).join('')}
                </select>
            </div>
            ${currentFarm ? `
                <div class="form-group">
                    <label>Nome do Farm</label>
                    <input type="text" id="edit-farm-name" value="${currentFarm.name}">
                </div>
                <div style="display: flex; gap: 10px;">
                    <button class="btn btn-primary" onclick="saveGeneral()">Salvar Alterações</button>
                    <button class="btn btn-danger" onclick="deleteFarm()">Excluir Farm</button>
                </div>
            ` : '<p>Nenhum farm encontrado. Crie um novo!</p>'}
        `);
    } else if (currentTab === 'items') {
        const selectedIdx = $('#creator-select-farm').val() || 0;
        const currentFarm = currentFarmData[selectedIdx];
        const items = currentFarm ? Object.entries(currentFarm.config.items) : [];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3>Itens do Farm</h3>
                <button class="btn btn-primary" onclick="addFarmItem()">+ Adicionar Item</button>
            </div>
            <div class="item-list">
                ${items.map(([key, val]) => `
                    <div class="farm-card" style="flex-direction: row; justify-content: space-between; padding: 10px 20px; align-items: center; margin-bottom: 10px; text-align: left;">
                        <div>
                            <span style="font-weight: 600;">${val.customName || key}</span><br>
                            <small style="color: var(--text-gray);">${key}</small>
                        </div>
                        <div style="display: flex; gap: 10px;">
                            <button class="btn btn-primary" onclick="editItem('${key}')"><i class="fa-solid fa-pen"></i></button>
                            <button class="btn btn-danger" onclick="removeItem('${key}')"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${items.length === 0 ? '<p>Nenhum item configurado para este farm.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'points') {
        const selectedIdx = $('#creator-select-farm').val() || 0;
        const currentFarm = currentFarmData[selectedIdx];
        const farmPoints = currentFarm ? currentFarm.config.items[Object.keys(currentFarm.config.items)[0]]?.points || [] : [];

        $panel.append(`
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3>Pontos de Farm</h3>
                <button class="btn btn-primary" onclick="addFarmPoint()">+ Adicionar Ponto</button>
            </div>
            <div class="point-list">
                ${farmPoints.map((p, i) => `
                    <div class="farm-card" style="flex-direction: row; justify-content: space-between; padding: 10px 20px; align-items: center; margin-bottom: 10px; text-align: left;">
                        <span>Ponto #${i + 1} (${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)})</span>
                        <div style="display: flex; gap: 10px;">
                            <button class="btn btn-primary" onclick="tpToPoint(${i})"><i class="fa-solid fa-location-crosshairs"></i> TP</button>
                            <button class="btn btn-danger" onclick="removePoint(${i})"><i class="fa-solid fa-trash"></i></button>
                        </div>
                    </div>
                `).join('')}
                ${farmPoints.length === 0 ? '<p>Configure os itens primeiro e depois adicione pontos.</p>' : ''}
            </div>
        `);
    } else if (currentTab === 'groups') {
        $panel.append(`<h3>Restrição de Grupos</h3><p>Configure as permissões de acesso (Job/Gang).</p>`);
    }
}

function addFarmPoint() {
    const selectedIdx = $('#creator-select-farm').val();
    const currentFarm = currentFarmData[selectedIdx];
    const firstItem = Object.keys(currentFarm.config.items)[0];
    
    if (!firstItem) {
        openModal('Aviso', '<p>Adicione pelo menos um item primeiro!</p>', () => true);
        return;
    }

    $.post(`https://${ResourceName}/addPoint`, JSON.stringify({
        farmKey: currentFarm.id,
        itemKey: firstItem
    }));
    $('#app').fadeOut(200); // Close NUI so user can see world while picking
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

// Logic for custom modals
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
