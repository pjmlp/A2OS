MODULE srRender;
IMPORT  Modules, Commands, WMWindowManager, Raster, Objects, Random,
Rectangles := WMRectangles,  Out  := KernelLog, Math, srBase,  srMath,  srRastermovie, srvoxels,
srRayEngine;

TYPE SREAL=srBase.SREAL;
TYPE Aperture = srBase.Aperture;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;
TYPE PT = srBase.PT;

TYPE SNAP = RECORD
	lookphi, looktheta : SREAL;
	aperture: Aperture;
	x,y,z,cdroll: SREAL;
	detail: SIGNED16;
END;

TYPE VoxWindow = OBJECT(WMWindowManager.DoubleBufferWindow)
VAR
	alive, alpha: BOOLEAN;
	i: SIGNED32;
	random: Random.Generator;
	camera: Camera;
	speed: SREAL;
	pointerlastx, pointerlasty: SIZE;
	pi: WMWindowManager.PointerInfo;
	px, pdx, py, pdy: SIZE;
	pkeys: SET;
	t1, t2, dt: SIGNED32;
	big, focus, voxconnect: BOOLEAN;
	connectvox: Voxel;
	Key: CHAR;
	movemode: CHAR;
	raysperframe: SIGNED32;

PROCEDURE & New*(W,H, i,j: SIGNED16; large: BOOLEAN);
BEGIN
	Init(W, H, TRUE);
	raysperframe:=W*H;
	manager := WMWindowManager.GetDefaultManager();
	manager.Add(i,j, SELF, { WMWindowManager.FlagFrame, WMWindowManager.FlagClose, WMWindowManager.FlagStayOnTop});
    WMWindowManager.LoadCursor("recticle.png", 3,3, pi);
	SetPointerInfo(pi);
	NEW(camera, SELF, W, H,large);
	speed := 0.0001;
	movemode := 'f';
END New;

(*PROCEDURE Draw*(canvas : Graphics.Canvas; w, h, q : SIGNED32);
BEGIN
	IF filter THEN Draw^(canvas, w, h, q) ELSE Draw^(canvas, w, h, 0) END
END Draw; *)

PROCEDURE FocusGot*;
BEGIN
	focus := TRUE;
END FocusGot;

PROCEDURE FocusLost*;
BEGIN
	focus := FALSE;
END FocusLost;

PROCEDURE Close*;
BEGIN
	srBase.worldalive := FALSE;
	Close^;
END Close;

PROCEDURE speedup*;
BEGIN
	speed := speed * 3 / 2;
END speedup;

PROCEDURE slowdown*;
BEGIN
	speed := speed * 2 / 3;
END slowdown;

PROCEDURE KeyEvent*(ucs : SIZE; flags : SET; keysym : SIZE);
BEGIN
	Key := CHR(ucs);
	CASE CHR(ucs) OF
		'+': speed := speed * 3 / 2;
		|'-': speed := speed * 2 / 3;
		|'f': foveate := ~foveate;
		|'1': camera.xjet(1);
		|'4': camera.xjet(-1);
		|'2': camera.yjet(1);
		|'5': camera.yjet(-1);
		|'3': camera.zjet(1);
		|'6': camera.zjet(-1);
		| ']': aperture.width := aperture.width * 101/99;
			aperture.height := aperture.height *101/99;
			camera.rayschanged  := TRUE;
		| '[': aperture.width := aperture.width * 99/101;
			aperture.height := aperture.height *99/101;
			camera.rayschanged  := TRUE;
		| 'q': Close;
		| 'i': INC(srBase.iterlimit);
		| 'o': DEC(srBase.iterlimit);
		| 'g': srBase.gravity := ~srBase.gravity; IF srBase.gravity THEN Out.String("G.g.g.raibbity!") END;
		| 'c': INC(srBase.rlimit);
		| 'C':  camera.connectray(px,py,voxconnect, connectvox);
		| 'v': DEC(srBase.rlimit);
		| '=': srBase.worldalive:=~srBase.worldalive;
		| 'r': camera.startrecording;
		| 'R': camera.stoprecording;
		| 'p': camera.startplaying;
		| 'P': camera.stopplaying;
		| 'd': DEATH := TRUE;
		| 'l': LOOK := TRUE;
		| 'k' : camera.filter := ~camera.filter;
		| 'z' :  cvx := cvx - 0.01
		| 'x' :  cvx := cvx + 0.01
		| 's': srRastermovie.snapshot(backImg)
		| 'm': srvoxels.trailswitch
		| 'h': hopcamera
		| ' ': camera.stop
		| 'Z': cdroll:= cdroll+1;
		| '*': srBase.STOPGO;
		| 't': TRAILS:=~TRAILS;
		ELSE
	END;
END KeyEvent;

PROCEDURE PointerDown*(x, y : SIZE; keys : SET);
BEGIN
	pointerlastx := x ; pointerlasty := y;
	pkeys := keys;
	srRayEngine.fast:=TRUE;
END PointerDown;

PROCEDURE deathray;
BEGIN
	camera.deathray(pointerlastx,pointerlasty)
END deathray;

PROCEDURE PointerUp*(x, y : SIZE; keys : SET);
BEGIN
	pkeys := keys;
	DEATH:=FALSE;
	srRayEngine.fast:=FALSE;
END PointerUp;

PROCEDURE PointerMove*(x, y : SIZE; keys : SET);
BEGIN
	pdx := px - x; pdy := py - y;
	px := ABS(x); py := ABS(y); pkeys := keys;
END PointerMove;

PROCEDURE PointerLeave*;
BEGIN
	focus := FALSE;
END PointerLeave;

PROCEDURE WheelMove*(dz : SIZE);
BEGIN
    	camera.up(dz/10);
END WheelMove;

PROCEDURE move;
BEGIN
	IF movieplaying THEN camera.movietick;
	ELSE
		IF movemode = "f" THEN fly ELSE pan END;
		camera.tick;
	END
END move;

PROCEDURE fly;
BEGIN
	IF 0 IN pkeys THEN camera.forward(px,py) END ;
(*	IF 1 IN pkeys THEN cvl := cvl+pdx/44; cvu := cvu+pdy/44 END;*)
	IF 2 IN pkeys THEN camera.backward(px,py) END;
END fly;

PROCEDURE pan;
(*
BEGIN
	IF 0 IN pkeys THEN camera.forward(px,py);
	ELSIF 1 IN pkeys THEN cvl := cvl+pdx/4; camera.up(pdy)
	ELSIF 2 IN pkeys THEN camera.backward(px,py);
	END *)
END pan;

END VoxWindow;

TYPE Camera = OBJECT
VAR
	window: VoxWindow;
	random: Random.Generator;
	filter,rayschanged, ang1: BOOLEAN;
	fovealeft, fovearight, foveabottom, foveatop: SIGNED32;
	fovea: BOOLEAN;
	cam: srBase.PT;
	mode : Raster.Mode;
	pixel: Raster.Pixel;
	W,H: SIGNED16;
	XLOOK,YLOOK: SIGNED32;
	large: BOOLEAN;

PROCEDURE & init *(w: VoxWindow; width, height: SIGNED16; l: BOOLEAN);
BEGIN
	window := w;
	large:=l;
	W := width; H := height;
	Raster.InitMode(mode, Raster.srcCopy);
(*	lookray.theta := 3.14;
	lookray.phi := 3.14;
	aperture.width := 4;
	aperture.height := 3;
	angletoray(lookray);
	framecount := 0;
	fovealeft :=  - 30;
	fovearight := fovealeft + 60;
	foveabottom := (H DIV 2) - 30;
	foveatop := foveabottom + 60;
	rayschanged := TRUE;
*)
END init;

PROCEDURE move;
VAR
	x,y,z,d: SREAL;
	v: Voxel;
	proberay: Ray;

PROCEDURE normalize(VAR x,y,z,d: SREAL);
BEGIN
	d := Math.sqrt(x*x + y*y+z*z);
	x := x/d; y := y/d; z:=z/d
END normalize;

PROCEDURE denormalize(VAR x,y,z,d: SREAL);
BEGIN
	x := x*d; y := y*d; z:=z*d
END denormalize;

BEGIN
	x := cx + cvx; y := cy + cvy; z := cz + cvz;
	v := block.probe(x,y,z);
	IF  (v=NIL) OR v.passable THEN
		cx := x; cy := y; cz := z;
		srBase.clamp3(cx,cy,cz);
	ELSIF v#NIL THEN
		proberay := srBase.blankray;
		normalize(cvx,cvy,cvz,d);
		proberay.dxyz.x := cvx;
		proberay.dxyz.y := cvy;
		proberay.dxyz.z := cvz;
		denormalize(cvx,cvy,cvz,d);
		proberay.xyz.x := cx;
		proberay.xyz.y := cy;
		proberay.xyz.z := cz;
		block.probeShade(proberay,cvx,cvy,cvz);
	END;
END move;

PROCEDURE snap;
BEGIN
	frames[frame].x := cx;
	frames[frame].y := cy;
	frames[frame].z := cz;
	frames[frame].looktheta := lookray.theta;
	frames[frame].lookphi := lookray.phi;
	frames[frame].aperture := aperture;
	frames[frame].cdroll := cdroll;
	frames[frame].detail := srBase.rlimit;
	INC(frame);
	IF frame MOD 50 = 0 THEN Out.Int(frame, 10); Out.String(" frames"); Out.Ln; END;
	IF frame > 9999 THEN movierecording := FALSE;  Out.String(" out of film") END
END snap;

PROCEDURE stop;
BEGIN
	cvx := 0;
	cvy := 0;
	cvz := 0;
END stop;

PROCEDURE movietick;
VAR
	s: SNAP;
BEGIN
	s := frames[tickframe];
	cam.x := s.x;
	cam.y := s.y;
	cam.z := s.z;
	lookray.theta := s.looktheta;
	lookray.phi := s.lookphi;
	aperture := s.aperture;
	cdroll:=s.cdroll;
	srBase.rlimit := s.detail;
	INC(tickframe);
	IF tickframe >= frame THEN stopplaying END;
END movietick;

PROCEDURE startrecording;
BEGIN
	movierecording := TRUE;
	Out.String("movie recording on");
	srBase.RESET;
END startrecording;

PROCEDURE stoprecording;
BEGIN
	movierecording := FALSE;
	Out.String("movie recording off")
END stoprecording;

PROCEDURE startplaying;
BEGIN
	tickframe := 0;
	srBase.RESET;
	movieplaying := TRUE;
	Out.String("movie playing on");
END startplaying;

PROCEDURE stopplaying;
BEGIN
	movieplaying := FALSE;
	srBase.worldalive :=FALSE;
	Out.String("movie playing off")
END stopplaying;

PROCEDURE deathray (x, y: SIZE);
BEGIN
	IF large THEN
		block.deathray(srBase.lrays[x,y]);
	ELSE
		block.deathray(srBase.rays[x,y]);
	END
END deathray;

PROCEDURE mutateray (x, y: SIGNED32);
BEGIN
	IF (x < W) & (y < H) THEN
		block.mutateray(srBase.rays[x ,y]);
	END
END mutateray;

PROCEDURE connectray(x, y: SIZE; VAR connection: BOOLEAN; VAR vox: Voxel);
BEGIN
	IF  (x < W) & (y < H) THEN
		block.connectray(srBase.rays[x ,y], connection, vox);
	END
END connectray;

PROCEDURE forward (x, y: SIZE);
VAR
	speed: SREAL;
BEGIN
	x:=x MOD W;
	y:=y MOD H;
	IF large THEN
		left((x - (W/2)) / 150);
		up((y - (H/2)) / 150);
		speed := window.speed;
		cvx := cvx + srBase.lrays[x,y].dxyz.x * speed;
		cvy := cvy + srBase.lrays[x,y].dxyz.y * speed;
		cvz := cvz + srBase.lrays[x,y].dxyz.z * speed;
		clampspeed(cvx,cvy,cvz, 1);
	ELSE
		left((x - (W/2)) / 150);
		up((y - (H/2)) / 150);
		speed := window.speed;
		cvx := cvx + srBase.rays[x,y].dxyz.x * speed;
		cvy := cvy + srBase.rays[x,y].dxyz.y * speed;
		cvz := cvz + srBase.rays[x,y].dxyz.z * speed;
		clampspeed(cvx,cvy,cvz, 1);
	END
END forward;

PROCEDURE backward (x, y: SIZE);
VAR
	speed: SREAL;
BEGIN
	x:=x MOD W;
	y:=y MOD H;
		IF large THEN
		left((x - (W/2)) / 50);
		up((y - (H/2)) / 50);
		speed := window.speed;
		cvx := cvx - srBase.lrays[x,y].dxyz.x * speed;
		cvy := cvy - srBase.lrays[x,y].dxyz.y * speed;
		cvz := cvz - srBase.lrays[x,y].dxyz.z * speed;
		clampspeed(cvx,cvy,cvz, 1);
	ELSE
		left((x - (W/2)) / 50);
		up((y - (H/2)) / 50);
		speed := window.speed;
		cvx := cvx - srBase.rays[x,y].dxyz.x * speed;
		cvy := cvy - srBase.rays[x,y].dxyz.y * speed;
		cvz := cvz - srBase.rays[x,y].dxyz.z * speed;
		clampspeed(cvx,cvy,cvz, 1);
	END
END backward;

PROCEDURE xjet(jet: SREAL);
BEGIN
	cvx:=cvx+(jet*window.speed);
END xjet;

PROCEDURE yjet(jet: SREAL);
BEGIN
	cvy:=cvy+(jet*window.speed);
END yjet;

PROCEDURE zjet(jet: SREAL);
BEGIN
	cvz:=cvz+(jet*window.speed);
END zjet;

PROCEDURE  jitter;
END jitter;

(* PROCEDURE initrays;
VAR
	i, j: SIGNED32;
	theta, phi, dtheta, dphi: SREAL;
BEGIN
	dtheta := aperture.width / W;
	dphi := aperture.height / H;
	theta := lookray.theta - aperture.width / 2; 	(*left*)
	FOR i := 0 TO W - 1 DO
		theta := theta + dtheta;
		phi := lookray.phi - aperture.height / 2; 	(*bottom*)
		FOR j := 0 TO H - 1 DO
			phi := phi + dphi;
			srBase.rays[i, j] := srBase.blankray;
			srBase.rays[i, j].theta := theta;
			srBase.rays[i, j].phi := phi;
			angletoray(srBase.rays[i, j]);
			srBase.rays[i, j].xyz := cam;
			srBase.rays[i, j].lxyz := cam;
		END
	END;
END initrays; *)

PROCEDURE initrays;
VAR
	i, j: SIGNED32;
	theta, phi, dtheta, dphi: SREAL;
	down: srBase.PT;
	look: srBase.Ray;
BEGIN
	dtheta := aperture.width / W;
	dphi := aperture.height / H;
	theta := lookray.theta-aperture.width / 2;
	srBase.setPT(down,0,1,0);
	IF large THEN
		look:=srBase.LLOOK;
		FOR i := 0 TO W - 1 DO
			theta := theta + dtheta;
			phi :=  -aperture.height / 2; 	(*bottom*)
			FOR j := 0 TO H - 1 DO
				phi := phi + dphi;
				srBase.lrays[i, j] := srBase.blankray;
				srBase.lrays[i, j].theta := theta;
				srBase.lrays[i, j].phi := phi;
				angletoray(srBase.lrays[i, j]);
		  	  	srMath.orrot(srBase.lrays[i, j].dxyz, down, theta);
		  	  	srMath.orrot(srBase.lrays[i, j].dxyz, look.dxyz, cdroll);
				ddray(srBase.lrays[i, j]);
				srBase.lrays[i, j].xyz := cam;
				srBase.lrays[i, j].lxyz := cam;
			END
		END
	ELSE
		look:=srBase.LOOK;
		FOR i := 0 TO W - 1 DO
			theta := theta + dtheta;
			phi :=  -aperture.height / 2; 	(*bottom*)
			FOR j := 0 TO H - 1 DO
				phi := phi + dphi;
				srBase.rays[i, j] := srBase.blankray;
				srBase.rays[i, j].theta := theta;
				srBase.rays[i, j].phi := phi;
				angletoray(srBase.rays[i, j]);
		  	  	srMath.orrot(srBase.rays[i, j].dxyz, down, theta);
		  	  	srMath.orrot(srBase.rays[i, j].dxyz, look.dxyz, cdroll);
				ddray(srBase.rays[i, j]);
				srBase.rays[i, j].xyz := cam;
				srBase.rays[i, j].lxyz := cam;
			END
		END
	END
END initrays;

PROCEDURE foveate(x,y: SIGNED32);
BEGIN
	fovealeft := (x-foveasize) MOD W;
	fovearight := (x+foveasize) MOD W;
	foveadown := (y-foveasize) MOD H;
	foveaup := (y+foveasize) MOD H;
END foveate;

PROCEDURE tracetiled;
VAR
	i, j: SIGNED32;
	pixel : Raster.Pixel;
BEGIN
	block.tick;
	IF large THEN
		srRayEngine.lgo;
		IF srRayEngine.fast THEN
			FOR i := 0 TO W-1 BY 2 DO
				FOR j := 0 TO H-1 BY 2 DO
					Raster.SetRGB(pixel, ENTIER(srBase.limage[i,j].red * 255), ENTIER(srBase.limage[i,j].green * 255),
					ENTIER(srBase.limage[i,j].blue * 255));
					Raster.Fill(window.backImg,i,j,i+2,j+2,pixel, mode);
				END
			END
		ELSE
			FOR i := 0 TO W-1 DO
				FOR j := 0 TO H-1 DO
					Raster.SetRGB(pixel, ENTIER(srBase.limage[i,j].red * 255), ENTIER(srBase.limage[i,j].green * 255),
					ENTIER(srBase.limage[i,j].blue * 255));
					Raster.Put(window.backImg,i,j,pixel, mode);
				END
			END
		END
	ELSE
		srRayEngine.go;
		FOR i := 0 TO W-1 DO
			FOR j := 0 TO H-1 DO
				Raster.SetRGB(pixel, ENTIER(srBase.image[i,j].red * 255), ENTIER(srBase.image[i,j].green * 255),
				ENTIER(srBase.image[i,j].blue * 255));
				Raster.Put(window.backImg,i,j,pixel, mode);
			END
		END
	END;
	window.Swap;
	window.Invalidate(Rectangles.MakeRect(0, 0, window.GetWidth(), window.GetHeight()))
END tracetiled;

(*PROCEDURE trace(VAR ray: srBase.Ray);
BEGIN
	block.Shade(ray);
	srBase.clamp3(ray.r, ray.g, ray.b);
END trace;*)

PROCEDURE left (th: SREAL);
BEGIN
	lookray.theta := lookray.theta + th/10;
	IF lookray.theta > 6.28 THEN lookray.theta := 0 END
END left;

PROCEDURE up (ph: SREAL);
BEGIN
	cdroll:=cdroll+ph/10;
	IF cdroll>6.28 THEN cdroll:=0 END;
END up;

PROCEDURE trail(a,b:PT);
VAR
	v: Voxel;
BEGIN
	v:=block.probe(b.x,b.y,b.z);
	srvoxels.cameratrail(block,a,b);
END trail;

PROCEDURE tick;
VAR
	oldcam:PT;
BEGIN
	oldcam:=cam;
	cam.x := cx; cam.y := cy; cam.z := cz;
	IF TRAILS THEN trail(oldcam,cam) END;
	IF srBase.gravity THEN cvz := cvz+1/10000 END;
	cvx := cvx*38/39; cvy := cvy*38/39; cvz := cvz* 38/39; cvl := cvl*18/19; cvu := cvu*18/19;
(*	croll := croll + cdroll/150;
	cdroll:=cdroll*16/19; *)
	move;
	left(cvl);
	up(cvu);
END tick;

END Camera;

TYPE MainLoop=OBJECT
VAR
	t1, t2, dt,f: SIGNED32;
	fr: SREAL;
	framerate, lastframerate: SIGNED32;

BEGIN {ACTIVE, PRIORITY(Objects.Normal)}
	win:=window;
	REPEAT
		srBase.tick;
		block:= srBase.world;
		IF lwindow.focus THEN win := lwindow END;
		IF window.focus THEN win := window END;
		win.camera.initrays;
		IF DEATH THEN
			srBase.deathflag:=FALSE;
			win.deathray;
			DEATH:=FALSE
		END;
		win.move;
		win.camera.tracetiled;
		IF movierecording THEN win.camera.snap END;
		IF movieplaying THEN
			srRastermovie.snap(win.img);
		END
	UNTIL ~srBase.worldalive;
	Close;
END MainLoop;

VAR
	main: MainLoop;
	win, window, lwindow: VoxWindow;
	cx, cy, cz, cvx, cvy, cvz, cvl, cvu: SREAL;
	cdroll: SREAL;
	lookray: Ray;
	rand: Random.Generator;
	wcount: SIGNED16;
	frame, tickframe: SIGNED32;
	frames: ARRAY 10000 OF SNAP;
	movierecording, movieplaying: BOOLEAN;
	foveate: BOOLEAN;
	foveasize, foveadown, foveaup: SIGNED32;
	block: Voxel;
	DEATH, LOOK, TRAILS: BOOLEAN;
	tracetiled: BOOLEAN;
	aperture: Aperture;
	framecount: SIGNED32;

PROCEDURE angletoray(VAR ray: srBase.Ray);
(* VAR d: SREAL; *)
BEGIN
	ray.dxyz.x := srMath.cos(ray.theta) * srMath.cos(ray.phi);
	ray.dxyz.y := srMath.sin(ray.theta) * srMath.cos(ray.phi);
	ray.dxyz.z := srMath.sin(ray.phi);
(*	d := Math.sqrt(ray.dxyz.x*ray.dxyz.x + ray.dxyz.y* ray.dxyz.y+ray.dxyz.z*ray.dxyz.z);  (* Norma! Liza! Ray! Front and center, oh dark thirty!*)
	ray.dxyz.x := ray.dxyz.x/d;
	ray.dxyz.y := ray.dxyz.y/d;
	ray.dxyz.z := ray.dxyz.z/d; *)
	ray.ddxyz.x := ray.dxyz.x/1000000;
	ray.ddxyz.y := ray.dxyz.y/1000000;
	ray.ddxyz.z := ray.dxyz.z/1000000;
END angletoray;
(*
PROCEDURE raytangle(VAR ray: srBase.Ray);
VAR x,y, z: SREAL;
BEGIN
	x := ray.xyz.x; y := ray.xyz.y; z := 0;
	srBase.normalize(x,y,z);
	ray.theta := srMath.arccos(x);
	ray.phi := srMath.arccos(1-ray.dxyz.z);
END raytangle;

PROCEDURE carttosph(VAR p: PT; theta, phi: SREAL);
BEGIN
	p.x := srMath.cos(theta) * srMath.cos(phi);
	p.y := srMath.sin(theta) * srMath.cos(phi);
	p.z := srMath.sin(phi);
END carttosph;

PROCEDURE sphtocart( p: PT; VAR theta, phi: SREAL);
VAR
	x,y, z: SREAL;
BEGIN
	x := p.x; y := p.y; z := 0;
	srBase.normalize(x,y,z);
	theta := srMath.arccos(x);
	phi := srMath.arccos(1-p.z);
END sphtocart;

PROCEDURE gray(VAR ray: Ray);
VAR
	gray: SREAL;
BEGIN
	gray := (ray.r + ray.g + ray.b)/3;
	ray.r := gray; ray.g := gray; ray.b := gray;
END gray;
*)

PROCEDURE ddray(VAR ray: srBase.Ray);
BEGIN
	ray.ddxyz.x := ray.dxyz.x/10000;
	ray.ddxyz.y := ray.dxyz.y/10000;
	ray.ddxyz.z := ray.dxyz.z/10000;
END ddray;

PROCEDURE clampspeed(VAR r,g,b: SREAL; speed: SREAL);
BEGIN
	IF r < -speed THEN r := -speed ELSIF r>speed THEN r := speed END;
	IF g < -speed THEN g := -speed ELSIF g>speed THEN g := speed END;
	IF b < -100 THEN b := -speed ELSIF b>speed THEN b := speed END;
END clampspeed;

PROCEDURE Demo*;
VAR res : INTEGER; msg : ARRAY 128 OF CHAR;
BEGIN
	Commands.Call("Notepad.Open srReadMe.Text", {Commands.Wait}, res, msg); (* ignore res *)
	Open;
END Demo;

PROCEDURE Open*;
BEGIN
	srBase.worldalive := TRUE;
	NEW(window, srBase.W, srBase.H, 100, 100, FALSE);
	NEW(lwindow, srBase.LW, srBase.LH, 150, 200, TRUE);
	NEW(main);
END Open;

PROCEDURE Close*;
BEGIN
	 IF window# NIL THEN window.Close; window := NIL END;
	 IF lwindow#NIL THEN lwindow.Close; lwindow:=NIL; END;
END Close;

PROCEDURE hopcamera;
BEGIN
	cx :=1/2+1/117; cy := 1/2+1/117; cz := 1/2-1/117;
END hopcamera;

BEGIN
	lookray.theta := 3.14;
	lookray.phi := 3.14;
	aperture.width := 3/2;
	aperture.height := 2;
	angletoray(lookray);
	framecount := 0;
(****************************************)
	wcount := 0;
	NEW(rand);
	block:= srBase.world;
	ASSERT(block# NIL);
	srRayEngine.setBlock(block);
	Modules.InstallTermHandler(Close);
	foveasize := 30;
	hopcamera;  (* PLACE CAMERA *)
	tracetiled:=TRUE;
END srRender.

srRender.Open ~

System.Free srRender srvoxels ~

System.Free
srBase
srRayEngine
srMath
srE
srGL
srHex
srImage
srVoxel
srVoxel2
srVoxel3
srVolShader
srVoxel4
srVoxel5
srM2Space
srM3Space
srM5Space
srM6Space
srRastermovie
srTexVox
srThermoCell
srTree
sr3DTexture
srLifeVox
srvoxels
srRender
TuringCoatWnd~

PC.Compile \s
srBase.Mod
srRayEngine.Mod
srMath.Mod
srE.Mod
srGL.Mod
srHex.Mod
srImage.Mod
srVoxel.Mod
srVoxel2.Mod
srVoxel3.Mod
srVolShader.Mod
srVoxel4.Mod
srVoxel5.Mod
srM2Space.Mod
srM3Space.Mod
srM5Space.Mod
srM6Space.Mod
srRastermovie.Mod
srTexVox.Mod
srThermoCell.Mod
srTree.Mod
sr3DTexture.Mod
srLifeVox.Mod
srvoxels.Mod
srRender.Mod
TuringCoatWnd.Mod~

#############################################

Tar.Create tracer.Tar
srBase.Mod
srRayEngine.Mod
srMath.Mod
srE.Mod
srGL.Mod
srHex.Mod
srImage.Mod
srVoxel.Mod
srVoxel2.Mod
srVoxel3.Mod
srVolShader.Mod
srVoxel4.Mod
srVoxel5.Mod
srM2Space.Mod
srM3Space.Mod
srM5Space.Mod
srM6Space.Mod
srRastermovie.Mod
srTexVox.Mod
srThermoCell.Mod
srTree.Mod
sr3DTexture.Mod
srLifeVox.Mod
srvoxels.Mod
srRender.Mod
TuringCoatWnd.Mod
srskin.skin
ateney.jpg
BathingInterrupted.jpg
DESTROYUSA.jpg
~
