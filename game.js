(() => {
    const byId = (id) => document.getElementById(id);

    const ui = {
        lobbyView: byId("lobby-view"),
        gameView: byId("game-view"),
        gameContainer: byId("game-container"),
        startButton: byId("startButton"),
        backLobbyButton: byId("back-lobby-btn"),
        status: byId("game-status"),
        toast: byId("toast")
    };

    const optionalButtonIds = [
        "garage-btn",
        "missions-btn",
        "settings-btn",
        "leaderboard-btn",
        "daily-btn",
        "auth-signin-btn",
        "logout-btn"
    ];

    const setStatus = (text) => {
        if (ui.status) {
            ui.status.textContent = text;
        }
    };

    const showToast = (message) => {
        if (!ui.toast) {
            return;
        }

        ui.toast.textContent = message;
        ui.toast.classList.add("show");

        window.clearTimeout(showToast.timeoutId);
        showToast.timeoutId = window.setTimeout(() => {
            ui.toast.classList.remove("show");
        }, 2200);
    };

    const setView = (mode) => {
        const showLobby = mode === "lobby";

        if (ui.lobbyView) {
            ui.lobbyView.classList.toggle("hidden", !showLobby);
        }
        if (ui.gameView) {
            ui.gameView.classList.toggle("hidden", showLobby);
        }
    };

    const requiredElements = [
        "lobbyView",
        "gameView",
        "gameContainer",
        "startButton",
        "backLobbyButton"
    ];

    const missing = requiredElements.filter((name) => !ui[name]);
    if (missing.length > 0) {
        console.error("Ridge Rush UI is missing required elements:", missing);
        return;
    }

    optionalButtonIds.forEach((id) => {
        const button = byId(id);
        if (!button) {
            return;
        }

        button.addEventListener("click", () => {
            showToast("This panel is currently disabled in this build.");
        });
    });

    if (typeof Phaser === "undefined") {
        setStatus("Phaser failed to load. Check CDN/network and reload.");
        showToast("Phaser failed to load.");
        return;
    }

    let phaserGame = null;

    class RaceScene extends Phaser.Scene {
        constructor() {
            super({ key: "RaceScene" });

            this.trackStep = 68;
            this.trackPoints = [];
            this.trackLength = 0;

            this.frontWheel = null;
            this.rearWheel = null;
            this.chassis = null;

            this.controls = null;
            this.windowKeyState = {
                up: false,
                down: false,
                left: false,
                right: false,
                w: false,
                s: false,
                a: false,
                d: false
            };
            this.onKeyDown = null;
            this.onKeyUp = null;

            this.progressBarWidth = 420;
            this.progressBarStartX = 0;
            this.progressPanel = null;
            this.progressTrack = null;
            this.progressFill = null;
            this.progressMarker = null;
            this.progressDistanceText = null;
            this.finishFlag = null;
            this.finishOverlayPanel = null;
            this.finishTitleText = null;
            this.finishHintText = null;

            this.startX = 0;
            this.goalDistance = 3200;
            this.raceFinished = false;
            this.finishDistanceMeters = 0;

            this.groundContactPairs = new Set();
            this.jumpCooldownUntil = 0;
            this.lastGroundedAt = 0;
            this.prevUpPressed = false;

            this.frameTextureKey = "rrx-bike-frame-v2";
            this.wheelTextureKey = "rrx-bike-wheel-v2";

            this.wheelRadius = 31;
            this.wheelOffsetX = 62;
            this.suspensionAnchorY = 6;
            this.suspensionRestLength = 10;
            this.wheelOffsetY = this.suspensionAnchorY + this.suspensionRestLength;

            this.chassisBodyWidth = 124;
            this.chassisBodyHeight = 26;
            this.terrainSurfaceOffsetY = 24;
        }

        preload() {
            // No external assets needed.
        }

        create() {
            this.generateTrackProfile();
            this.createSkyLayers();
            this.createTrackVisuals();
            this.createTrackPhysics();
            this.createVehicleTextures();
            this.createVehicle();
            this.setupGroundDetection();
            this.setupInput();
            this.createHud();

            this.startX = this.chassis.x;

            this.cameras.main.startFollow(this.chassis, true, 0.08, 0.08);
            this.cameras.main.setLerp(0.08, 0.08);

            this.game.canvas.setAttribute("tabindex", "0");
            this.game.canvas.focus();
            this.input.on("pointerdown", () => this.game.canvas.focus());

            this.raceFinished = false;
            this.finishDistanceMeters = 0;
            this.updateHud(0, 0);
        }

        generateTrackProfile() {
            const basePointCount = 260;
            const baseY = 585;
            const flatPoints = 20;
            const estimatedSpawnX = 420;
            const destinationPadding = 1800;
            const requiredTrackLength = estimatedSpawnX + this.goalDistance * 10 + destinationPadding;
            const pointCount = Math.max(basePointCount, Math.ceil(requiredTrackLength / this.trackStep));

            this.trackPoints = [];

            for (let i = 0; i <= pointCount; i += 1) {
                const x = i * this.trackStep;

                let y;
                if (i <= flatPoints) {
                    y = baseY;
                }
                else {
                    const t = i - flatPoints;
                    y = baseY
                        + Math.sin(t * 0.16) * 28
                        + Math.sin(t * 0.036) * 66
                        + Math.cos(t * 0.09) * 16;
                }

                y = Phaser.Math.Clamp(y, 450, 710);
                this.trackPoints.push({ x, y });
            }

            this.trackLength = this.trackPoints[this.trackPoints.length - 1].x;

            this.matter.world.setBounds(-2000, -1700, this.trackLength + 4500, 5200);
            this.cameras.main.setBounds(-900, -520, this.trackLength + 1800, 2200);
        }

        createSkyLayers() {
            this.cameras.main.setBackgroundColor(0x8dd4ff);

            const sky = this.add.graphics();
            sky.fillGradientStyle(0xc2ecff, 0xc2ecff, 0x70b6ef, 0x70b6ef, 1);
            sky.fillRect(-3000, -2200, this.trackLength + 7000, 3200);
            sky.setDepth(-90);

            this.add.circle(930, 140, 74, 0xffefad, 0.95).setDepth(-88).setScrollFactor(0.01);
            this.add.circle(930, 140, 110, 0xffefad, 0.24).setDepth(-89).setScrollFactor(0.01);

            this.drawMountainBand({
                baseY: 445,
                ampA: 65,
                ampB: 35,
                freqA: 0.0018,
                freqB: 0.0041,
                color: 0x7fa5cf,
                alpha: 0.62,
                depth: -60,
                scrollFactor: 0.15
            });

            this.drawMountainBand({
                baseY: 520,
                ampA: 52,
                ampB: 27,
                freqA: 0.0023,
                freqB: 0.0049,
                color: 0x6d95bf,
                alpha: 0.78,
                depth: -48,
                scrollFactor: 0.25
            });

            this.drawCloud(560, 130, -76, 0.05);
            this.drawCloud(1300, 160, -76, 0.06);
            this.drawCloud(1840, 120, -76, 0.04);
        }

        drawMountainBand(config) {
            const graphics = this.add.graphics().setDepth(config.depth).setScrollFactor(config.scrollFactor);
            const left = -1500;
            const right = this.trackLength + 2600;

            graphics.fillStyle(config.color, config.alpha);
            graphics.beginPath();
            graphics.moveTo(left, 1300);

            for (let x = left; x <= right; x += 72) {
                const y = config.baseY
                    + Math.sin((x + 180) * config.freqA) * config.ampA
                    + Math.cos((x - 90) * config.freqB) * config.ampB;
                graphics.lineTo(x, y);
            }

            graphics.lineTo(right, 1300);
            graphics.closePath();
            graphics.fillPath();
        }

        drawCloud(x, y, depth, scrollFactor) {
            const cloud = this.add.container(x, y).setDepth(depth).setScrollFactor(scrollFactor);
            cloud.add(this.add.ellipse(0, 0, 120, 46, 0xffffff, 0.45));
            cloud.add(this.add.ellipse(-36, -8, 74, 34, 0xffffff, 0.5));
            cloud.add(this.add.ellipse(38, -10, 82, 36, 0xffffff, 0.48));
        }

        createTrackVisuals() {
            const first = this.trackPoints[0];
            const last = this.trackPoints[this.trackPoints.length - 1];

            const dirt = this.add.graphics().setDepth(-12);
            dirt.fillStyle(0x855632, 1);
            dirt.beginPath();
            dirt.moveTo(first.x - 420, 1400);
            for (let i = 0; i < this.trackPoints.length; i += 1) {
                const point = this.trackPoints[i];
                dirt.lineTo(point.x, point.y + 62);
            }
            dirt.lineTo(last.x + 420, 1400);
            dirt.closePath();
            dirt.fillPath();

            const grass = this.add.graphics().setDepth(-10);
            grass.lineStyle(28, 0x5f9f2f, 1);
            for (let i = 0; i < this.trackPoints.length - 1; i += 1) {
                const current = this.trackPoints[i];
                const next = this.trackPoints[i + 1];
                grass.lineBetween(current.x, current.y + 36, next.x, next.y + 36);
            }
            grass.lineStyle(10, 0x86d24b, 1);
            for (let i = 0; i < this.trackPoints.length - 1; i += 1) {
                const current = this.trackPoints[i];
                const next = this.trackPoints[i + 1];
                grass.lineBetween(current.x, current.y + 24, next.x, next.y + 24);
            }

            for (let i = 22; i < this.trackPoints.length; i += 18) {
                const point = this.trackPoints[i];
                this.add.rectangle(point.x, point.y - 38, 14, 48, 0x5b3d22, 0.95).setDepth(-9);
                this.add.circle(point.x, point.y - 68, 26, 0x4d962e, 0.95).setDepth(-9);
                this.add.circle(point.x - 16, point.y - 74, 18, 0x4d962e, 0.95).setDepth(-9);
                this.add.circle(point.x + 16, point.y - 74, 18, 0x4d962e, 0.95).setDepth(-9);
            }
        }

        createTrackPhysics() {
            const terrainThickness = 120;

            for (let i = 0; i < this.trackPoints.length - 1; i += 1) {
                const first = this.trackPoints[i];
                const second = this.trackPoints[i + 1];

                const x1 = first.x;
                const y1 = first.y + this.terrainSurfaceOffsetY;
                const x2 = second.x;
                const y2 = second.y + this.terrainSurfaceOffsetY;

                const dx = x2 - x1;
                const dy = y2 - y1;
                const length = Math.sqrt(dx * dx + dy * dy);
                const angle = Math.atan2(dy, dx);
                const centerX = (x1 + x2) * 0.5;
                const centerY = (y1 + y2) * 0.5 + terrainThickness * 0.5;

                this.matter.add.rectangle(centerX, centerY, length + 8, terrainThickness, {
                    isStatic: true,
                    angle,
                    friction: 1.08,
                    frictionStatic: 2.1,
                    restitution: 0
                });
            }

            this.matter.add.rectangle(this.trackLength * 0.5, 1550, this.trackLength + 3400, 1800, {
                isStatic: true,
                friction: 1.08,
                frictionStatic: 2.1,
                restitution: 0
            });
        }

        createVehicleTextures() {
            const graphics = this.make.graphics({ x: 0, y: 0, add: false });

            if (!this.textures.exists(this.frameTextureKey)) {
                graphics.clear();
                const rearHubX = 48;
                const frontHubX = 172;
                const hubY = 70;

                graphics.lineStyle(7, 0xd3482c, 1);
                graphics.lineBetween(rearHubX, hubY, 106, 54);
                graphics.lineBetween(106, 54, 146, 58);
                graphics.lineBetween(146, 58, frontHubX, hubY);
                graphics.lineBetween(106, 54, 88, 34);
                graphics.lineBetween(88, 34, 126, 34);
                graphics.lineBetween(126, 34, 146, 58);

                graphics.lineStyle(6, 0x252d36, 1);
                graphics.lineBetween(102, 54, 114, 70);
                graphics.lineBetween(114, 70, rearHubX, hubY);
                graphics.lineBetween(150, 58, 184, 40);
                graphics.lineBetween(178, 39, 194, 32);

                graphics.fillStyle(0x12161c, 1);
                graphics.fillRoundedRect(80, 29, 34, 8, 4);

                graphics.fillStyle(0xd3482c, 1);
                graphics.fillRoundedRect(111, 40, 30, 15, 7);
                graphics.fillStyle(0xe56d43, 1);
                graphics.fillRoundedRect(114, 43, 23, 8, 4);

                graphics.fillStyle(0x2f3a45, 1);
                graphics.fillRoundedRect(106, 20, 24, 20, 8);
                graphics.fillRoundedRect(116, 34, 8, 20, 3);
                graphics.fillRoundedRect(117, 53, 7, 17, 3);
                graphics.fillRoundedRect(108, 57, 20, 6, 3);

                graphics.fillStyle(0xfacea3, 1);
                graphics.fillCircle(118, 14, 7);
                graphics.fillStyle(0xbe3f28, 1);
                graphics.fillRoundedRect(112, 8, 13, 6, 2);
                graphics.fillStyle(0x1f2730, 1);
                graphics.fillRoundedRect(108, 16, 20, 4, 2);

                graphics.fillStyle(0x1f2730, 1);
                graphics.fillCircle(rearHubX, hubY, 5);
                graphics.fillCircle(frontHubX, hubY, 5);

                graphics.generateTexture(this.frameTextureKey, 220, 108);
            }

            if (!this.textures.exists(this.wheelTextureKey)) {
                graphics.clear();
                const center = 34;

                graphics.fillStyle(0x0e1217, 1);
                graphics.fillCircle(center, center, 34);
                graphics.fillStyle(0x1a2129, 1);
                graphics.fillCircle(center, center, 30);

                for (let i = 0; i < 28; i += 1) {
                    const angle = (Math.PI * 2 * i) / 28;
                    const treadX = center + Math.cos(angle) * 31;
                    const treadY = center + Math.sin(angle) * 31;
                    const treadColor = i % 2 === 0 ? 0x0f141a : 0x252d37;
                    graphics.fillStyle(treadColor, 1);
                    graphics.fillCircle(treadX, treadY, 1.9);
                }

                graphics.fillStyle(0x717b88, 1);
                graphics.fillCircle(center, center, 20);
                graphics.fillStyle(0x8c96a3, 1);
                graphics.fillCircle(center, center, 16);
                graphics.fillStyle(0xa9b1bc, 1);
                graphics.fillCircle(center, center, 6);

                graphics.lineStyle(2, 0x4c5661, 1);
                for (let i = 0; i < 10; i += 1) {
                    const angle = (Math.PI * 2 * i) / 10;
                    const spokeX = center + Math.cos(angle) * 18;
                    const spokeY = center + Math.sin(angle) * 18;
                    graphics.lineBetween(center, center, spokeX, spokeY);
                }

                graphics.generateTexture(this.wheelTextureKey, 68, 68);
            }

            graphics.destroy();
        }

        createVehicle() {
            const MatterLib = Phaser.Physics.Matter.Matter;
            const spawnX = 420;
            const spawnY = this.getCarRestYAt(spawnX);
            const wheelCenterY = spawnY + this.wheelOffsetY;
            const collisionGroup = MatterLib.Body.nextGroup(true);

            const chassisBody = MatterLib.Bodies.rectangle(
                spawnX,
                spawnY,
                this.chassisBodyWidth,
                this.chassisBodyHeight,
                {
                    chamfer: { radius: 9 }
                }
            );
            chassisBody.friction = 0.26;
            chassisBody.frictionStatic = 0.5;
            chassisBody.frictionAir = 0.02;
            chassisBody.restitution = 0;
            chassisBody.collisionFilter.group = collisionGroup;
            MatterLib.Body.setMass(chassisBody, 18.5);

            const rearWheelBody = MatterLib.Bodies.circle(
                spawnX - this.wheelOffsetX,
                wheelCenterY,
                this.wheelRadius,
                {
                    friction: 1.2,
                    frictionStatic: 2.45,
                    frictionAir: 0.018,
                    restitution: 0
                }
            );
            rearWheelBody.collisionFilter.group = collisionGroup;
            MatterLib.Body.setMass(rearWheelBody, 7.6);

            const frontWheelBody = MatterLib.Bodies.circle(
                spawnX + this.wheelOffsetX,
                wheelCenterY,
                this.wheelRadius,
                {
                    friction: 1.2,
                    frictionStatic: 2.45,
                    frictionAir: 0.018,
                    restitution: 0
                }
            );
            frontWheelBody.collisionFilter.group = collisionGroup;
            MatterLib.Body.setMass(frontWheelBody, 7.4);

            this.chassis = this.matter.add.image(spawnX, spawnY, this.frameTextureKey);
            this.chassis.setExistingBody(chassisBody);
            this.chassis.setOrigin(0.5, 0.5);
            this.chassis.setDepth(6);
            this.chassis.setSleepThreshold(20);

            this.rearWheel = this.matter.add.image(spawnX - this.wheelOffsetX, wheelCenterY, this.wheelTextureKey);
            this.rearWheel.setExistingBody(rearWheelBody);
            this.rearWheel.setOrigin(0.5, 0.5).setDepth(5);

            this.frontWheel = this.matter.add.image(spawnX + this.wheelOffsetX, wheelCenterY, this.wheelTextureKey);
            this.frontWheel.setExistingBody(frontWheelBody);
            this.frontWheel.setOrigin(0.5, 0.5).setDepth(5);

            const suspensionStiffness = 0.998;
            const suspensionDamping = 0.36;
            const axleStiffness = 1;
            const axleDamping = 0.43;
            const axleLength = this.suspensionRestLength;
            const addWheelSuspension = (wheelBody, anchorX) => {
                this.matter.add.constraint(chassisBody, wheelBody, this.suspensionRestLength, suspensionStiffness, {
                    pointA: { x: anchorX - 5, y: this.suspensionAnchorY },
                    pointB: { x: -4, y: 0 },
                    damping: suspensionDamping
                });

                this.matter.add.constraint(chassisBody, wheelBody, this.suspensionRestLength, suspensionStiffness, {
                    pointA: { x: anchorX + 5, y: this.suspensionAnchorY },
                    pointB: { x: 4, y: 0 },
                    damping: suspensionDamping
                });

                this.matter.add.constraint(chassisBody, wheelBody, axleLength, axleStiffness, {
                    pointA: { x: anchorX, y: this.suspensionAnchorY },
                    pointB: { x: 0, y: 0 },
                    damping: axleDamping
                });
            };

            addWheelSuspension(rearWheelBody, -this.wheelOffsetX);
            addWheelSuspension(frontWheelBody, this.wheelOffsetX);
        }

        setupGroundDetection() {
            const contactKey = (pair) => {
                const bodyAId = pair.bodyA.id;
                const bodyBId = pair.bodyB.id;
                return bodyAId < bodyBId ? bodyAId + "-" + bodyBId : bodyBId + "-" + bodyAId;
            };

            const isWheelBody = (body) => body === this.rearWheel.body || body === this.frontWheel.body;

            this.matter.world.on("collisionstart", (event) => {
                for (let i = 0; i < event.pairs.length; i += 1) {
                    const pair = event.pairs[i];
                    if (isWheelBody(pair.bodyA) || isWheelBody(pair.bodyB)) {
                        this.groundContactPairs.add(contactKey(pair));
                    }
                }
            });

            this.matter.world.on("collisionend", (event) => {
                for (let i = 0; i < event.pairs.length; i += 1) {
                    const pair = event.pairs[i];
                    if (isWheelBody(pair.bodyA) || isWheelBody(pair.bodyB)) {
                        this.groundContactPairs.delete(contactKey(pair));
                    }
                }
            });
        }

        isGrounded() {
            if (this.groundContactPairs.size > 0) {
                return true;
            }

            if (!this.rearWheel || !this.frontWheel) {
                return false;
            }

            const wheelNearSurface = (wheel) => {
                const roadY = this.getRoadSurfaceYAt(wheel.x);
                const distanceToRoad = wheel.y + this.wheelRadius - roadY;
                const verticalSpeed = Math.abs(wheel.body.velocity.y);
                return distanceToRoad > -4 && verticalSpeed < 2.8;
            };

            return wheelNearSurface(this.rearWheel) || wheelNearSurface(this.frontWheel);
        }

        setupInput() {
            this.input.keyboard.enabled = true;
            this.input.keyboard.preventDefault = true;

            this.input.keyboard.addCapture([
                Phaser.Input.Keyboard.KeyCodes.LEFT,
                Phaser.Input.Keyboard.KeyCodes.RIGHT,
                Phaser.Input.Keyboard.KeyCodes.UP,
                Phaser.Input.Keyboard.KeyCodes.DOWN
            ]);

            this.controls = this.input.keyboard.addKeys({
                up: Phaser.Input.Keyboard.KeyCodes.UP,
                down: Phaser.Input.Keyboard.KeyCodes.DOWN,
                left: Phaser.Input.Keyboard.KeyCodes.LEFT,
                right: Phaser.Input.Keyboard.KeyCodes.RIGHT,
                w: Phaser.Input.Keyboard.KeyCodes.W,
                s: Phaser.Input.Keyboard.KeyCodes.S,
                a: Phaser.Input.Keyboard.KeyCodes.A,
                d: Phaser.Input.Keyboard.KeyCodes.D
            });

            const applyKeyState = (event, isDown) => {
                const key = event.key;
                if (!key) {
                    return;
                }

                const lower = key.toLowerCase();
                switch (lower) {
                    case "arrowup":
                        this.windowKeyState.up = isDown;
                        event.preventDefault();
                        break;
                    case "arrowdown":
                        this.windowKeyState.down = isDown;
                        event.preventDefault();
                        break;
                    case "arrowleft":
                        this.windowKeyState.left = isDown;
                        event.preventDefault();
                        break;
                    case "arrowright":
                        this.windowKeyState.right = isDown;
                        event.preventDefault();
                        break;
                    case "w":
                        this.windowKeyState.w = isDown;
                        break;
                    case "s":
                        this.windowKeyState.s = isDown;
                        break;
                    case "a":
                        this.windowKeyState.a = isDown;
                        break;
                    case "d":
                        this.windowKeyState.d = isDown;
                        break;
                    default:
                        break;
                }
            };

            this.onKeyDown = (event) => applyKeyState(event, true);
            this.onKeyUp = (event) => applyKeyState(event, false);
            window.addEventListener("keydown", this.onKeyDown);
            window.addEventListener("keyup", this.onKeyUp);

            this.events.once("shutdown", () => this.teardownInputFallback());
            this.events.once("destroy", () => this.teardownInputFallback());
        }

        teardownInputFallback() {
            if (this.onKeyDown) {
                window.removeEventListener("keydown", this.onKeyDown);
                this.onKeyDown = null;
            }

            if (this.onKeyUp) {
                window.removeEventListener("keyup", this.onKeyUp);
                this.onKeyUp = null;
            }
        }

        createHud() {
            this.progressPanel = this.add.rectangle(0, 0, 520, 52, 0x1c2835, 0.52)
                .setStrokeStyle(1, 0xaed3ee, 0.3)
                .setScrollFactor(0)
                .setDepth(39);

            this.progressTrack = this.add.rectangle(0, 0, this.progressBarWidth, 12, 0x2f4657, 0.92)
                .setStrokeStyle(2, 0x95caef, 0.72)
                .setScrollFactor(0)
                .setDepth(40);

            this.progressFill = this.add.rectangle(0, 0, 0, 8, 0xf2b046, 1)
                .setOrigin(0, 0.5)
                .setScrollFactor(0)
                .setDepth(41);

            this.progressMarker = this.add.circle(0, 0, 7, 0xfff0c4, 1)
                .setStrokeStyle(2, 0x273643, 1)
                .setScrollFactor(0)
                .setDepth(42);

            this.finishFlag = this.add.container(0, 0).setScrollFactor(0).setDepth(42);
            const flagPole = this.add.rectangle(0, 0, 3, 24, 0xf6fbff, 0.95).setOrigin(0.5, 1);
            const flagBase = this.add.rectangle(0, 1, 8, 3, 0x23313e, 1).setOrigin(0.5, 0);
            const flagWhite = this.add.rectangle(11, -20, 18, 12, 0xffffff, 1).setOrigin(0, 0);
            const flagDarkA = this.add.rectangle(11, -20, 9, 6, 0x243341, 1).setOrigin(0, 0);
            const flagDarkB = this.add.rectangle(20, -14, 9, 6, 0x243341, 1).setOrigin(0, 0);
            this.finishFlag.add([flagPole, flagBase, flagWhite, flagDarkA, flagDarkB]);

            this.progressDistanceText = this.add.text(0, 0, "0 m", {
                fontFamily: "Sora, sans-serif",
                fontSize: "18px",
                color: "#ffffff",
                stroke: "#1f2b38",
                strokeThickness: 3
            })
                .setOrigin(0.5)
                .setScrollFactor(0)
                .setDepth(41);

            this.finishOverlayPanel = this.add.rectangle(0, 0, 420, 130, 0x0f1c29, 0.84)
                .setStrokeStyle(2, 0xaed3ee, 0.56)
                .setScrollFactor(0)
                .setDepth(70)
                .setVisible(false);

            this.finishTitleText = this.add.text(0, 0, "FINISH!", {
                fontFamily: "Bebas Neue, sans-serif",
                fontSize: "64px",
                color: "#f8f4e8",
                stroke: "#172636",
                strokeThickness: 6
            })
                .setOrigin(0.5)
                .setScrollFactor(0)
                .setDepth(71)
                .setVisible(false);

            this.finishHintText = this.add.text(0, 0, "Press Back To Menu", {
                fontFamily: "Sora, sans-serif",
                fontSize: "18px",
                color: "#dcebf7",
                stroke: "#172636",
                strokeThickness: 4
            })
                .setOrigin(0.5)
                .setScrollFactor(0)
                .setDepth(71)
                .setVisible(false);

            this.layoutHud();
            this.scale.on("resize", () => {
                this.layoutHud();
            });
        }

        layoutHud() {
            const centerX = this.scale.width * 0.5;
            const barY = 30;

            this.progressBarStartX = centerX - this.progressBarWidth * 0.5;

            this.progressPanel.setPosition(centerX, barY + 4);
            this.progressTrack.setPosition(centerX, barY);
            this.progressFill.setPosition(this.progressBarStartX, barY);
            this.progressMarker.setPosition(this.progressBarStartX, barY);
            this.progressDistanceText.setPosition(centerX, barY + 24);
            this.finishFlag.setPosition(centerX + this.progressBarWidth * 0.5 + 14, barY + 1);

            const finishPanelY = this.scale.height * 0.47;
            this.finishOverlayPanel.setPosition(centerX, finishPanelY);
            this.finishTitleText.setPosition(centerX, finishPanelY - 20);
            this.finishHintText.setPosition(centerX, finishPanelY + 28);
        }

        sampleTrackY(x) {
            const clampedX = Phaser.Math.Clamp(x, this.trackPoints[0].x, this.trackLength);
            const index = Phaser.Math.Clamp(Math.floor(clampedX / this.trackStep), 0, this.trackPoints.length - 2);
            const first = this.trackPoints[index];
            const second = this.trackPoints[index + 1];
            const localT = (clampedX - first.x) / (second.x - first.x);
            return Phaser.Math.Linear(first.y, second.y, localT);
        }

        getRoadSurfaceYAt(x) {
            return this.sampleTrackY(x) + this.terrainSurfaceOffsetY;
        }

        getCarRestYAt(x) {
            const rearSurfaceY = this.getRoadSurfaceYAt(x - this.wheelOffsetX);
            const frontSurfaceY = this.getRoadSurfaceYAt(x + this.wheelOffsetX);

            const supportSurfaceY = Math.min(rearSurfaceY, frontSurfaceY);
            return supportSurfaceY - this.wheelRadius - this.wheelOffsetY;
        }

        readInputState() {
            const controls = this.controls;
            return {
                up: controls.up.isDown || controls.w.isDown || this.windowKeyState.up || this.windowKeyState.w,
                down: controls.down.isDown || controls.s.isDown || this.windowKeyState.down || this.windowKeyState.s,
                left: controls.left.isDown || controls.a.isDown || this.windowKeyState.left || this.windowKeyState.a,
                right: controls.right.isDown || controls.d.isDown || this.windowKeyState.right || this.windowKeyState.d
            };
        }

        repairVehicleStructure() {
            if (!this.chassis || !this.rearWheel || !this.frontWheel) {
                return;
            }

            const MatterLib = Phaser.Physics.Matter.Matter;
            const chassisBody = this.chassis.body;
            const maxWheelStretch = this.suspensionRestLength + 6;
            const repairLerp = 0.42;

            const stabilizeWheel = (wheel, sideSign) => {
                const wheelBody = wheel.body;
                const expectedX = chassisBody.position.x + sideSign * this.wheelOffsetX;
                const expectedY = chassisBody.position.y + this.wheelOffsetY;

                const dx = wheelBody.position.x - expectedX;
                const dy = wheelBody.position.y - expectedY;
                const distance = Math.sqrt(dx * dx + dy * dy);

                if (distance > maxWheelStretch) {
                    MatterLib.Body.setPosition(wheelBody, {
                        x: Phaser.Math.Linear(wheelBody.position.x, expectedX, repairLerp),
                        y: Phaser.Math.Linear(wheelBody.position.y, expectedY, repairLerp)
                    });

                    MatterLib.Body.setVelocity(wheelBody, {
                        x: wheelBody.velocity.x * 0.66,
                        y: wheelBody.velocity.y * 0.66
                    });
                }
            };

            stabilizeWheel(this.rearWheel, -1);
            stabilizeWheel(this.frontWheel, 1);
        }

        updateHud(distanceMeters, progress) {
            this.progressFill.width = this.progressBarWidth * progress;
            this.progressMarker.x = this.progressBarStartX + this.progressBarWidth * progress;
            this.progressDistanceText.setText(distanceMeters + " m");

            if (!this.raceFinished) {
                setStatus(distanceMeters + " m");
            }
        }

        freezeVehicleMotion() {
            if (!this.chassis || !this.rearWheel || !this.frontWheel) {
                return;
            }

            const MatterLib = Phaser.Physics.Matter.Matter;
            const bodies = [this.chassis.body, this.rearWheel.body, this.frontWheel.body];

            for (let i = 0; i < bodies.length; i += 1) {
                const body = bodies[i];
                MatterLib.Body.setVelocity(body, { x: 0, y: 0 });
                MatterLib.Body.setAngularVelocity(body, 0);
                body.force.x = 0;
                body.force.y = 0;
                body.torque = 0;
            }

            this.chassis.setIgnoreGravity(true);
            this.rearWheel.setIgnoreGravity(true);
            this.frontWheel.setIgnoreGravity(true);
        }

        completeRace(distanceMeters) {
            if (this.raceFinished) {
                return;
            }

            this.raceFinished = true;
            this.finishDistanceMeters = Math.max(this.goalDistance, distanceMeters);
            this.freezeVehicleMotion();

            this.finishOverlayPanel.setVisible(true).setAlpha(0);
            this.finishTitleText.setVisible(true).setAlpha(0);
            this.finishHintText.setVisible(true).setAlpha(0);
            this.finishHintText.setText(this.finishDistanceMeters + " m reached - Press Back To Menu");

            this.tweens.add({
                targets: [this.finishOverlayPanel, this.finishTitleText, this.finishHintText],
                alpha: 1,
                duration: 260,
                ease: "Sine.Out"
            });

            setStatus("Finished! " + this.finishDistanceMeters + " m");
            showToast("Destination reached. Race completed.");
        }

        update() {
            if (!this.chassis || !this.frontWheel || !this.rearWheel) {
                return;
            }

            if (this.raceFinished) {
                this.freezeVehicleMotion();
                this.updateHud(this.finishDistanceMeters || this.goalDistance, 1);
                return;
            }

            const input = this.readInputState();
            const accelerateInput = input.right && !input.left;
            const reverseInput = input.left && !input.right;
            const brakeInput = input.left && input.right;
            const descendInput = input.down && !input.up;
            const upHeld = input.up;
            const jumpPressed = upHeld && !this.prevUpPressed;

            const MatterLib = Phaser.Physics.Matter.Matter;
            const chassisBody = this.chassis.body;
            const rearWheelBody = this.rearWheel.body;
            const frontWheelBody = this.frontWheel.body;
            const grounded = this.isGrounded();
            if (grounded) {
                this.lastGroundedAt = this.time.now;
            }

            const forwardWheelTarget = grounded ? 2.45 : 1.62;
            const reverseWheelTarget = grounded ? -2.02 : -1.32;
            const driveSpinLerp = grounded ? 0.2 : 0.12;
            const frontAssistRatio = 0.74;
            const maxWheelSpin = 2.9;
            const forwardAssist = grounded ? 0.019 : 0.009;
            const reverseAssist = grounded ? 0.016 : 0.008;
            const brakeGrip = 0.52;
            const brakeLinearDamping = grounded ? 0.76 : 0.88;
            const coastingGrip = grounded ? 0.985 : 0.994;
            const downForce = grounded ? 0.03 : 0.018;
            const jumpVerticalBoost = 8.6;
            const jumpForwardBoost = 1.55;
            const maxForwardSpeed = 10.8;
            const maxReverseSpeed = -7.2;
            const jumpGraceWindow = 140;

            if (accelerateInput) {
                const rearSpin = Phaser.Math.Linear(rearWheelBody.angularVelocity, forwardWheelTarget, driveSpinLerp);
                const frontSpin = Phaser.Math.Linear(frontWheelBody.angularVelocity, forwardWheelTarget * frontAssistRatio, driveSpinLerp);

                MatterLib.Body.setAngularVelocity(rearWheelBody, rearSpin);
                MatterLib.Body.setAngularVelocity(frontWheelBody, frontSpin);
                MatterLib.Body.applyForce(chassisBody, chassisBody.position, { x: forwardAssist, y: 0 });

                if (chassisBody.velocity.x < maxForwardSpeed) {
                    MatterLib.Body.setVelocity(chassisBody, {
                        x: Math.min(chassisBody.velocity.x + 0.07, maxForwardSpeed),
                        y: chassisBody.velocity.y
                    });
                }
            }

            if (reverseInput) {
                const rearSpin = Phaser.Math.Linear(rearWheelBody.angularVelocity, reverseWheelTarget, driveSpinLerp);
                const frontSpin = Phaser.Math.Linear(frontWheelBody.angularVelocity, reverseWheelTarget * frontAssistRatio, driveSpinLerp);

                MatterLib.Body.setAngularVelocity(rearWheelBody, rearSpin);
                MatterLib.Body.setAngularVelocity(frontWheelBody, frontSpin);
                MatterLib.Body.applyForce(chassisBody, chassisBody.position, { x: -reverseAssist, y: 0 });

                if (chassisBody.velocity.x > maxReverseSpeed) {
                    MatterLib.Body.setVelocity(chassisBody, {
                        x: Math.max(chassisBody.velocity.x - 0.065, maxReverseSpeed),
                        y: chassisBody.velocity.y
                    });
                }
            }

            if (brakeInput) {
                MatterLib.Body.setAngularVelocity(rearWheelBody, rearWheelBody.angularVelocity * brakeGrip);
                MatterLib.Body.setAngularVelocity(frontWheelBody, frontWheelBody.angularVelocity * brakeGrip);
                MatterLib.Body.setVelocity(chassisBody, {
                    x: chassisBody.velocity.x * brakeLinearDamping,
                    y: chassisBody.velocity.y
                });

                if (Math.abs(chassisBody.velocity.x) < 0.18) {
                    MatterLib.Body.setVelocity(chassisBody, {
                        x: 0,
                        y: chassisBody.velocity.y
                    });
                }
            }

            if (!accelerateInput && !reverseInput && !brakeInput) {
                MatterLib.Body.setAngularVelocity(rearWheelBody, rearWheelBody.angularVelocity * coastingGrip);
                MatterLib.Body.setAngularVelocity(frontWheelBody, frontWheelBody.angularVelocity * coastingGrip);
            }

            MatterLib.Body.setAngularVelocity(
                rearWheelBody,
                Phaser.Math.Clamp(rearWheelBody.angularVelocity, -maxWheelSpin, maxWheelSpin)
            );
            MatterLib.Body.setAngularVelocity(
                frontWheelBody,
                Phaser.Math.Clamp(frontWheelBody.angularVelocity, -maxWheelSpin, maxWheelSpin)
            );

            const canJump = grounded || (this.time.now - this.lastGroundedAt <= jumpGraceWindow);

            if (jumpPressed && canJump && this.time.now >= this.jumpCooldownUntil) {
                const upVector = {
                    x: Math.sin(chassisBody.angle),
                    y: -Math.cos(chassisBody.angle)
                };

                MatterLib.Body.setVelocity(chassisBody, {
                    x: chassisBody.velocity.x + upVector.x * jumpForwardBoost,
                    y: chassisBody.velocity.y + upVector.y * jumpVerticalBoost
                });

                this.jumpCooldownUntil = this.time.now + 320;
            }

            if (descendInput) {
                MatterLib.Body.applyForce(chassisBody, chassisBody.position, { x: 0, y: downForce });
                MatterLib.Body.applyForce(rearWheelBody, rearWheelBody.position, { x: 0, y: downForce * 0.45 });
                MatterLib.Body.applyForce(frontWheelBody, frontWheelBody.position, { x: 0, y: downForce * 0.45 });
            }

            this.prevUpPressed = upHeld;
            this.repairVehicleStructure();

            const distanceMeters = Math.max(0, Math.round((this.chassis.x - this.startX) / 10));
            if (distanceMeters >= this.goalDistance) {
                this.completeRace(distanceMeters);
                this.updateHud(this.goalDistance, 1);
                return;
            }

            const progress = Phaser.Math.Clamp(distanceMeters / this.goalDistance, 0, 1);
            this.updateHud(distanceMeters, progress);
        }
    }

    const destroyGame = () => {
        if (phaserGame) {
            phaserGame.destroy(true);
            phaserGame = null;
        }
        ui.gameContainer.innerHTML = "";
    };

    const startRace = () => {
        destroyGame();
        setView("game");

        phaserGame = new Phaser.Game({
            type: Phaser.AUTO,
            parent: ui.gameContainer,
            width: 1280,
            height: 720,
            backgroundColor: "#8dd4ff",
            scale: {
                mode: Phaser.Scale.FIT,
                autoCenter: Phaser.Scale.CENTER_BOTH,
                width: 1280,
                height: 720
            },
            physics: {
                default: "matter",
                matter: {
                    gravity: { y: 1 },
                    positionIterations: 10,
                    velocityIterations: 8,
                    constraintIterations: 4,
                    debug: false
                }
            },
            scene: [RaceScene]
        });
    };

    const returnToLobby = () => {
        destroyGame();
        setView("lobby");
        setStatus("Race not started.");
    };

    ui.startButton.addEventListener("click", startRace);
    ui.backLobbyButton.addEventListener("click", returnToLobby);

    setView("lobby");
    setStatus("Race not started.");
})();
