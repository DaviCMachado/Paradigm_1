let currentRoomId = null;
let currentPlayerName = null;
let board = Array(3).fill(null).map(() => Array(3).fill(null)); // Inicializa como matriz 3x3

// Função para criar uma nova sala
async function createRoom() {
    const roomId = prompt('Digite o nome da sala:');
    console.log(`Tentando criar sala: ${roomId}`); // Log para depuração
    if (roomId) {
        try {
            const response = await fetch(`/sala/${roomId}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            console.log(`Resposta ao criar sala: ${response.status}`); // Log para depuração
            const data = await response.json();
            console.log('Dados recebidos:', data); // Log dos dados recebidos

            if (response.ok) {
                currentRoomId = roomId;
                alert(`Sala criada! ID da sala: ${currentRoomId}`);
                document.getElementById('gameBoard').style.display = 'block';
                resetBoard();
            } else {
                alert(data.error || 'Erro ao criar sala');
            }
        } catch (error) {
            console.error('Erro ao criar sala:', error);
            alert('Erro ao criar sala');
        }
    }
}

// Função para entrar em uma sala existente
async function joinRoom() {
    const roomId = prompt('Digite o ID da sala para entrar:');
    const playerName = prompt('Digite seu nome:');
    console.log(`Tentando entrar na sala: ${roomId}, Nome do jogador: ${playerName}`); // Log para depuração
    if (roomId && playerName) {
        try {
            const response = await fetch(`/sala/${roomId}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            console.log(`Resposta ao entrar na sala: ${response.status}`); // Log para depuração
            const data = await response.json();
            if (response.ok) {
                currentRoomId = roomId;
                currentPlayerName = playerName;
                alert(`Entrou na sala com ID: ${roomId}`);
                document.getElementById('gameBoard').style.display = 'block';
                fetchBoard();
            } else {
                alert(data.error || 'Erro ao entrar na sala');
            }
        } catch (error) {
            console.error('Erro ao entrar na sala:', error);
            alert('Erro ao entrar na sala');
        }
    }
}

async function fetchBoard() {
    const roomId = 'minhaSala'; // O ID da sala deve ser dinâmico conforme necessário
    const response = await fetch(`/sala/${roomId}/tabuleiro`);
    const data = await response.json();

    if (data.error) {
        alert(data.error);
    } else {
        updateBoard(data); // Atualiza o tabuleiro
    }
}

// Chame fetchBoard() ao carregar a página ou após fazer uma jogada


function renderBoard() {
    console.log('Renderizando o tabuleiro'); // Log para depuração
    const boardDiv = document.getElementById('board');
    boardDiv.innerHTML = ''; // Limpa o tabuleiro anterior

    board.forEach((row, rowIndex) => {
        row.forEach((cell, colIndex) => {
            const cellDiv = document.createElement('div');
            cellDiv.className = 'cell';
            cellDiv.textContent = cell || ''; // Exibe X, O ou vazio
            cellDiv.addEventListener('click', () => makeMove(rowIndex, colIndex));
            boardDiv.appendChild(cellDiv);
            console.log(`Célula [${rowIndex}][${colIndex}]: ${cell || 'vazio'}`); // Log para depuração
        });
    });
}

// Função para fazer uma jogada
async function makeMove(row, col) {
    const roomId = 'minhaSala'; // O ID da sala deve ser dinâmico conforme necessário
    const response = await fetch(`/sala/${roomId}/jogar`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ row, col }),
    });

    const data = await response.json();

    if (data.error) {
        alert(data.error);
    } else {
        updateBoard(data.board); // Função para atualizar o tabuleiro na interface
        alert(data.message); // Exibe a mensagem de status
    }
}

// Função para atualizar o tabuleiro
function updateBoard(board) {
    board.forEach((row, rowIndex) => {
        row.forEach((cell, colIndex) => {
            const cellElement = document.getElementById(`cell-${rowIndex}-${colIndex}`);
            cellElement.innerText = cell ? cell : '';
        });
    });
}


// Função para reiniciar o tabuleiro
async function restartGame() {
    console.log(`Reiniciando o jogo para a sala: ${currentRoomId}`); // Log para depuração
    if (currentRoomId) {
        try {
            const response = await fetch(`/sala/${currentRoomId}/reiniciar`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            console.log(`Resposta ao reiniciar jogo: ${response.status}`); // Log para depuração
            const data = await response.json();
            if (response.ok) {
                alert(data.message);
                resetBoard();
            } else {
                alert(data.error || 'Erro ao reiniciar o jogo');
            }
        } catch (error) {
            console.error('Erro ao reiniciar o jogo:', error);
        }
    }
}

// Função para reiniciar o tabuleiro localmente
function resetBoard() {
    board = Array(3).fill(null).map(() => Array(3).fill(null)); // Reinicia como matriz 3x3
    renderBoard();
}

document.addEventListener('DOMContentLoaded', () => {
    const createRoomButton = document.getElementById('createRoomButton');
    const joinRoomButton = document.getElementById('joinRoomButton');
    const restartGameButton = document.getElementById('restartGameButton');

    console.log(createRoomButton, joinRoomButton, restartGameButton); // Check if these are still null

    if (createRoomButton) {
        createRoomButton.addEventListener('click', createRoom);
    }
    if (joinRoomButton) {
        joinRoomButton.addEventListener('click', joinRoom);
    }
    if (restartGameButton) {
        restartGameButton.addEventListener('click', resetBoard);
    }
});
