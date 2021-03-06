MODULE WMGraphicsGfx; (** AUTHOR "Patrick Hunziker"; PURPOSE "use rich Gfx Business logic for WMWindowManager.Canvas"; *)

IMPORT Gfx, GfxBuffer, GfxRaster, GfxMatrix, GfxRegions, Raster, Strings, WMGraphics, WMWindowManager, KernelLog;

TYPE Canvas*= OBJECT(WMGraphics.BufferCanvas)
	VAR
		gfxContext-: GfxBuffer.Context;
		fillColor: SIGNED32;
		gfxStrokeColor: Gfx.Color;
		gfxFillColor: Gfx.Color;
		gfxLineWidth: FLOAT32;
		dashLength: FLOAT32;

		PROCEDURE &New*(img : Raster.Image);
		BEGIN
			New^(img);
			generator:=Strings.NewString("WMGraphicsGfx.GenCanvas");
			SetupDrawing;
		END New;

		PROCEDURE SetupDrawing;
		VAR m: GfxMatrix.Matrix;
		BEGIN
			NEW(gfxContext);
			GfxBuffer.Init(gfxContext, img(*GetImage()*));
			(*
			GfxBuffer.SetCompOp(gfxContext, Raster.srcOverDst);
			GfxRaster.ResetClip(gfxContext);
			GfxRegions.SetToRect(gfxContext.clipReg, SHORT(clipRect.l), SHORT(clipRect.t), SHORT(clipRect.r), SHORT(clipRect.b));
			GfxMatrix.Init(m,1,0,0,1,dx,dy); (* one to one coordinate system, translated by the component's origin *)
			Gfx.SetCTM(gfxContext,m);
			*)
			SetDashLength(0);
			SetLineWidth(1.0);
			SetColor(WMGraphics.Blue);
			SetFillColor(WMGraphics.Red);
		END SetupDrawing;

		PROCEDURE SetLineWidth*(w:FLOAT32);
		BEGIN
			gfxLineWidth:=w;
			Gfx.SetLineWidth(gfxContext,w);
		END SetLineWidth;

		(* set line color*)
		PROCEDURE SetColor*(color:WMGraphics.Color);
		BEGIN
			IF color#SELF.color THEN
				SetColor^(color);
				gfxStrokeColor:=ColorToGfxColor(color);
				Gfx.SetStrokeColor(gfxContext, gfxStrokeColor);
			END;
		END SetColor;

		(* set line color*)
		PROCEDURE SetDashLength*(dl:FLOAT32);
		VAR on,off: ARRAY 1 OF FLOAT32;
		BEGIN
			dashLength:=dl;
			IF dashLength > 0 THEN
				on[0] := dashLength; off[0] := dashLength; Gfx.SetDashPattern(gfxContext, on, off, 1, 0);
			END;
		END SetDashLength;

		(* set fill/font color*)
		PROCEDURE SetFillColor*(fillColor:SIGNED32);
		BEGIN
			IF fillColor#SELF.fillColor THEN
				SELF.fillColor := fillColor;
				gfxFillColor:=ColorToGfxColor(fillColor);
				Gfx.SetFillColor(gfxContext, gfxFillColor);
			END;
		END SetFillColor;

		PROCEDURE ColorToGfxColor(color:WMGraphics.Color):Gfx.Color;
			VAR gfxcolor:Gfx.Color;
		BEGIN
			gfxcolor.a := SIGNED16(color MOD 100H);
			gfxcolor.b := SIGNED16(color DIV 100H MOD 100H);
			gfxcolor.g := SIGNED16(color DIV 10000H MOD 100H);
			gfxcolor.r := SIGNED16(color DIV 1000000H MOD 100H);
			RETURN gfxcolor
		END ColorToGfxColor;

		PROCEDURE GfxColorToColor(gfxColor:Gfx.Color):WMGraphics.Color;
		BEGIN
			RETURN SIGNED32 (((SIGNED64(gfxColor.r*100H)+gfxColor.g)*100H+gfxColor.b)*100H+gfxColor.a)
		END GfxColorToColor;

		(* ????
		PROCEDURE SetFont*(f: WMGraphics.Font);
		BEGIN
			SetFont^(f);
			Gfx.SetFontName(gfxContext, f.name, SHORT(f.size));
		END SetFont;
		*)

		PROCEDURE DrawString*(x, y: SIZE; CONST text : ARRAY OF CHAR);
		BEGIN
			ASSERT(font#NIL);
			Gfx.DrawStringAt(gfxContext, x, y, text);
		END DrawString;

		PROCEDURE Line*(x0, y0, x1, y1 : SIZE; lineColor : WMGraphics.Color; mode : INTEGER); (*this is a heavy duty procedure that can be called millions of times in time-varying or scrolled graphs - optimize*)
		BEGIN
			IF lineColor # color THEN
				SetColor(lineColor);
			END;
			Gfx.DrawLine(gfxContext, dx+x0, dy+y0, dx+x1, dy+y1, {Gfx.Stroke}); (*may be refined by plotting to upper/lower boundary*)
			(* Performance issue: Gfx.DrawLine expects FLOAT32 coordinates;	inside of Gfx a  coordinate transformation and conversion from FLOAT32 to Integer pixel position will happen again *)
		END Line;

		(** draw circle in requested mode (clockwise if r > 0, counterclockwise if r < 0) **)
		PROCEDURE Circle(x,y,r:SIGNED32); (*tentative -this method will be changed*)
		BEGIN
			Gfx.DrawCircle(gfxContext, x,y,r, {Gfx.Stroke});
		END Circle;

		(*to be extended by various Gfx specific drawing primitives*)

	END Canvas;

PROCEDURE GenCanvas*(img:Raster.Image):WMGraphics.BufferCanvas; (* generator procedure *)
VAR c:Canvas;
BEGIN
	NEW(c,img); RETURN c (* img is NIL, needs a call of c.New(img) later on *)
END GenCanvas;

PROCEDURE Test*; (* will be removed *)
VAR w:WMWindowManager.BufferWindow; c: WMGraphics.BufferCanvas;
BEGIN
	NEW(w, 300,400, FALSE);
	w.SetCanvasGenerator(GenCanvas);
	c:=w.canvas;

	c.Fill(w.bounds, WMGraphics.Red, WMGraphics.ModeCopy);

	c(Canvas).SetDashLength(10);
	c.SetLineWidth(1);
	c.Line(50,50,100,100, WMGraphics.Blue, WMGraphics.ModeCopy);
	c.SetLineWidth(3);
	c.Line(50,50,120,110, WMGraphics.Blue, WMGraphics.ModeCopy);

	c.SetPixel (50,30, WMGraphics.White, WMGraphics.ModeCopy);

	c(Canvas).SetFillColor(WMGraphics.Yellow);
	c.DrawString(60,40,"Hello World");

	c.SetColor(WMGraphics.Black);
	c.SetLineWidth(3);
	c(Canvas).Circle(150,200, 100);

	WMWindowManager.DefaultAddWindow(w);
	w.Invalidate(w.bounds);
END Test;

END WMGraphicsGfx.

WMGraphicsGfx.Test ~
System.FreeDownTo WMGraphicsGfx ~

