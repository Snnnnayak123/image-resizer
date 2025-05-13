<!DOCTYPE html>
<html>
<head>
    <title>Flappy Bird with Graphics</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            background-color: #70c5ce;
            font-family: Arial, sans-serif;
            overflow: hidden;
        }
        
        #game-container {
            position: relative;
            width: 400px;
            height: 600px;
            overflow: hidden;
            background-color: #70c5ce;
            border: 2px solid #000;
        }
        
        #bird {
            position: absolute;
            width: 40px;
            height: 40px;
            left: 50px;
            top: 300px;
            z-index: 10;
        }
        
        .bird-body {
            position: absolute;
            width: 30px;
            height: 30px;
            background-color: #FFD700;
            border-radius: 50%;
            top: 5px;
            left: 5px;
        }
        
        .bird-wing {
            position: absolute;
            width: 20px;
            height: 15px;
            background-color: #FFA500;
            border-radius: 50%;
            top: 15px;
            left: 0;
            transform-origin: right center;
            animation: wingFlap 0.4s infinite alternate;
        }
        
        .bird-beak {
            position: absolute;
            width: 10px;
            height: 8px;
            background-color: #FF6347;
            border-radius: 2px;
            top: 15px;
            left: 35px;
        }
        
        .bird-eye {
            position: absolute;
            width: 8px;
            height: 8px;
            background-color: white;
            border-radius: 50%;
            top: 10px;
            left: 25px;
        }
        
        .bird-eye:after {
            content: '';
            position: absolute;
            width: 4px;
            height: 4px;
            background-color: black;
            border-radius: 50%;
            top: 2px;
            left: 2px;
        }
        
        .pipe {
            position: absolute;
            width: 60px;
            right: -60px;
            z-index: 5;
        }
        
        .pipe-top {
            background-color: #4CAF50;
            border-top: 5px solid #2E7D32;
            border-left: 5px solid #2E7D32;
            border-right: 5px solid #2E7D32;
            border-top-left-radius: 10px;
            border-top-right-radius: 10px;
            box-sizing: border-box;
        }
        
        .pipe-bottom {
            background-color: #4CAF50;
            border-bottom: 5px solid #2E7D32;
            border-left: 5px solid #2E7D32;
            border-right: 5px solid #2E7D32;
            border-bottom-left-radius: 10px;
            border-bottom-right-radius: 10px;
            box-sizing: border-box;
        }
        
        .pipe-end {
            position: absolute;
            width: 70px;
            height: 20px;
            background-color: #2E7D32;
            left: -5px;
            z-index: 1;
        }
        
        .pipe-top .pipe-end {
            bottom: -15px;
            border-bottom-left-radius: 5px;
            border-bottom-right-radius: 5px;
        }
        
        .pipe-bottom .pipe-end {
            top: -15px;
            border-top-left-radius: 5px;
            border-top-right-radius: 5px;
        }
        
        #score {
            position: absolute;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 36px;
            color: white;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
            z-index: 100;
            font-weight: bold;
        }
        
        #game-over {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background-color: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            display: none;
            z-index: 200;
        }
        
        #restart-btn {
            margin-top: 20px;
            padding: 10px 20px;
            background-color: #FFD700;
            color: #333;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
        }
        
        .ground {
            position: absolute;
            bottom: 0;
            width: 100%;
            height: 60px;
            background-color: #8B4513;
            z-index: 20;
        }
        
        @keyframes wingFlap {
            from { transform: rotate(-10deg); }
            to { transform: rotate(40deg); }
        }
    </style>
</head>
<body>
    <div id="game-container">
        <div id="bird">
            <div class="bird-body"></div>
            <div class="bird-wing"></div>
            <div class="bird-beak"></div>
            <div class="bird-eye"></div>
        </div>
        <div id="score">0</div>
        <div class="ground"></div>
        <div id="game-over">
            <h2>Game Over</h2>
            <p>Your score: <span id="final-score">0</span></p>
            <button id="restart-btn">Play Again</button>
        </div>
    </div>

    <script>
        // Game variables
        const bird = document.getElementById('bird');
        const gameContainer = document.getElementById('game-container');
        const scoreElement = document.getElementById('score');
        const gameOverElement = document.getElementById('game-over');
        const finalScoreElement = document.getElementById('final-score');
        const restartBtn = document.getElementById('restart-btn');
        
        let birdY = 300;
        let birdVelocity = 0;
        let gravity = 0.5;
        let jumpForce = -10;
        let gameRunning = true;
        let score = 0;
        let pipes = [];
        let pipeGap = 180;
        let pipeFrequency = 2000; // milliseconds
        let lastPipeTime = 0;
        let groundOffset = 0;
        let gameSpeed = 2;
        
        // Game loop
        function gameLoop(timestamp) {
            if (!gameRunning) return;
            
            updateBird();
            updatePipes();
            checkCollisions();
            render();
            
            requestAnimationFrame(gameLoop);
        }
        
        // Update bird position
        function updateBird() {
            birdVelocity += gravity;
            birdY += birdVelocity;
            
            // Rotate bird based on velocity
            let rotation = birdVelocity * 3;
            if (rotation > 30) rotation = 30;
            if (rotation < -20) rotation = -20;
            bird.style.transform = `rotate(${rotation}deg)`;
            
            // Keep bird within game bounds
            if (birdY < 0) {
                birdY = 0;
                birdVelocity = 0;
            }
            
            if (birdY > gameContainer.clientHeight - 60 - 40) {
                birdY = gameContainer.clientHeight - 60 - 40;
                gameOver();
            }
            
            bird.style.top = birdY + 'px';
        }
        
        // Create new pipes
        function createPipe() {
            const minHeight = 60;
            const maxHeight = gameContainer.clientHeight - pipeGap - minHeight - 60;
            const pipeHeight = Math.random() * (maxHeight - minHeight) + minHeight;
            
            // Top pipe
            const topPipe = document.createElement('div');
            topPipe.className = 'pipe pipe-top';
            topPipe.style.height = pipeHeight + 'px';
            topPipe.style.top = '0';
            
            const topPipeEnd = document.createElement('div');
            topPipeEnd.className = 'pipe-end';
            topPipe.appendChild(topPipeEnd);
            
            gameContainer.appendChild(topPipe);
            
            // Bottom pipe
            const bottomPipe = document.createElement('div');
            bottomPipe.className = 'pipe pipe-bottom';
            bottomPipe.style.height = (gameContainer.clientHeight - pipeHeight - pipeGap - 60) + 'px';
            bottomPipe.style.bottom = '60px';
            
            const bottomPipeEnd = document.createElement('div');
            bottomPipeEnd.className = 'pipe-end';
            bottomPipe.appendChild(bottomPipeEnd);
            
            gameContainer.appendChild(bottomPipe);
            
            pipes.push({
                top: topPipe,
                bottom: bottomPipe,
                x: gameContainer.clientWidth,
                passed: false
            });
        }
        
        // Update pipes position
        function updatePipes() {
            const currentTime = Date.now();
            if (currentTime - lastPipeTime > pipeFrequency) {
                createPipe();
                lastPipeTime = currentTime;
                
                // Increase difficulty
                if (score > 0 && score % 5 === 0) {
                    pipeFrequency = Math.max(1000, pipeFrequency - 100);
                    gameSpeed = Math.min(5, gameSpeed + 0.2);
                }
            }
            
            for (let i = pipes.length - 1; i >= 0; i--) {
                const pipe = pipes[i];
                pipe.x -= gameSpeed;
                
                pipe.top.style.left = pipe.x + 'px';
                pipe.bottom.style.left = pipe.x + 'px';
                
                // Check if bird passed the pipe
                if (!pipe.passed && pipe.x < 50 - 60) {
                    pipe.passed = true;
                    score++;
                    scoreElement.textContent = score;
                }
                
                // Remove pipes that are off screen
                if (pipe.x < -60) {
                    gameContainer.removeChild(pipe.top);
                    gameContainer.removeChild(pipe.bottom);
                    pipes.splice(i, 1);
                }
            }
        }
        
        // Check for collisions
        function checkCollisions() {
            const birdRect = {
                x: 50,
                y: birdY,
                width: 40,
                height: 40
            };
            
            // Ground collision
            if (birdY + 40 > gameContainer.clientHeight - 60) {
                gameOver();
                return;
            }
            
            for (const pipe of pipes) {
                const topPipeRect = {
                    x: pipe.x,
                    y: 0,
                    width: 60,
                    height: parseInt(pipe.top.style.height)
                };
                
                const bottomPipeRect = {
                    x: pipe.x,
                    y: gameContainer.clientHeight - parseInt(pipe.bottom.style.height) - 60,
                    width: 60,
                    height: parseInt(pipe.bottom.style.height)
                };
                
                if (isColliding(birdRect, topPipeRect) || isColliding(birdRect, bottomPipeRect)) {
                    gameOver();
                    break;
                }
            }
        }
        
        // Collision detection
        function isColliding(rect1, rect2) {
            return rect1.x < rect2.x + rect2.width &&
                   rect1.x + rect1.width > rect2.x &&
                   rect1.y < rect2.y + rect2.height &&
                   rect1.y + rect1.height > rect2.y;
        }
        
        // Render game
        function render() {
            bird.style.top = birdY + 'px';
        }
        
        // Game over
        function gameOver() {
            gameRunning = false;
            finalScoreElement.textContent = score;
            gameOverElement.style.display = 'block';
        }
        
        // Restart game
        function restartGame() {
            // Remove all pipes
            for (const pipe of pipes) {
                gameContainer.removeChild(pipe.top);
                gameContainer.removeChild(pipe.bottom);
            }
            pipes = [];
            
            // Reset game state
            birdY = 300;
            birdVelocity = 0;
            score = 0;
            scoreElement.textContent = '0';
            gameRunning = true;
            gameOverElement.style.display = 'none';
            pipeFrequency = 2000;
            gameSpeed = 2;
            
            // Reset bird rotation
            bird.style.transform = 'rotate(0deg)';
            
            // Restart game loop
            requestAnimationFrame(gameLoop);
        }
        
        // Event listeners
        document.addEventListener('keydown', (e) => {
            if ((e.code === 'Space' || e.code === 'ArrowUp') && gameRunning) {
                birdVelocity = jumpForce;
            }
        });
        
        gameContainer.addEventListener('click', () => {
            if (gameRunning) {
                birdVelocity = jumpForce;
            }
        });
        
        restartBtn.addEventListener('click', restartGame);
        
        // Start game
        requestAnimationFrame(gameLoop);
    </script>
</body>
</html>
