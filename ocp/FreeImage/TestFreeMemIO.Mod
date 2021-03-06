MODULE TestFreeMemIO; (** AUTHOR "fnecati"; PURPOSE "test module for freeimage' MemIO functions"; *)

IMPORT FI := FreeImageDll, Out:=KernelLog, Files, S:=SYSTEM,
	Commands;
	
			
(** Open an image file,  save it to memory and 
	later, load it from the memory and save it disk *)
PROCEDURE SaveMemIO*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;

	tdib, check: FI.FIBITMAP;
	fif, memfif: FI.IMAGE_FORMAT;
	hmem: FI.FIMEMORY;
	res: BOOLEAN;
	filesize: SIGNED32;
BEGIN
	IF ~context.arg.GetString(fname) THEN RETURN END;
	tdib := FI.LoadImage(fname, 0);


	IF tdib = NIL THEN
		Out.String(fname); Out.String(": Image NOT Loaded .."); Out.Ln();
		RETURN;
	END;

	(* open a memory handle *)
	hmem := FI.OpenMemory(0, 0);

	(* save the file to memory *)
	res := FI.SaveToMemory(fif, tdib, hmem, 0);

	(* at this point, hmem contains the entire PNG data in memory.
	the amount of space used by the memory is equal to file_size *)
	filesize := FI.TellMemory(hmem);
	Out.String("File size (bytes): "); Out.Int(filesize, 0); Out.Ln;

	(* its easy load an image from memory as well *)

	(* seek to the start of the memory stream *)
	res := FI.SeekMemory(hmem, 0, FI.SEEK_SET);

	(* get the file type *)
	memfif := FI.GetFileTypeFromMemory(hmem, 0);

	(* load an image from the memory handle *)
	check := FI.LoadFromMemory(memfif, hmem, 0);

	(* save as a regular file *)
	res := FI.SaveImage(check, "dump.png", FI.PNG_DEFAULT);

	(* make sure to free the data since FreeImage_SaveToMemory
	will cause it to be malloc'd *)
	FI.CloseMemory(hmem);
	FI.Unload(check);
	FI.Unload(tdib);
	(*			Out.String(fname$); Out.String(": Image Loaded .."); Out.Ln();

	Out.String('wxh: '); Out.Int(FI.GetWidth(tdib), 0);
	Out.Int(FI.GetHeight(tdib), 5); Out.Ln;
	Out.String("BPP: "); Out.Int(FI.GetBPP(tdib),0); Out.Ln;
	Window.ShowPicture(tdib, title$)
	*)
	Out.String("SaveMemIO finished, savet to dump.png file"); Out.Ln;
END SaveMemIO;

(* you could also have image data in memory via some other method, and just set
fmh.data to point to it, and set both fmh.datalen and fmh.filelen to the
size of that data, then FreeImage_LoadFromMemory could load the image from that memory *)

PROCEDURE LoadMemIO*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;
	tdib: FI.FIBITMAP;
	title: ARRAY 64 OF CHAR;
	fif: FI.IMAGE_FORMAT;
	hmem: FI.FIMEMORY;
	res: BOOLEAN;
	f: Files.File;
	rd: Files.Rider;
	membuf: POINTER TO ARRAY OF CHAR;
	bufsize: SIGNED32;
BEGIN
	IF ~context.arg.GetString(fname) THEN RETURN END;

	f := Files.Old(fname);
	IF f = NIL THEN
		Out.String(fname); Out.String(": Image NOT Loaded .."); Out.Ln();
		RETURN;
	END;
				
	bufsize := f.Length()(SIGNED32);
	Out.String("Length of "); Out.String(title); Out.Int(bufsize, 10);  
	Out.String(" bytes"); Out.Ln;
		
	NEW(membuf, bufsize);
	f.Set(rd, 0);

	f.ReadBytes(rd, membuf^, 0, bufsize);
	f.Close();

	(* attach the binary data to a memory stream *)
	hmem := FI.OpenMemory(ADDRESSOF(membuf^[0]), bufsize);
	(* get the file type *)
	fif := FI.GetFileTypeFromMemory(hmem, 0);

	(* load an image from the memory stream *)
	tdib := FI.LoadFromMemory(fif, hmem, 0);

	(* save as a regular file *)
	res := FI.SaveImage(tdib, "dump1.png", FI.PNG_DEFAULT);

	(* make sure to free the data since FreeImage_SaveToMemory
	will cause it to be malloc'd *)
	FI.Unload(tdib);
	FI.CloseMemory(hmem);
	membuf := NIL;
	Out.String("LoadMemIO finished, saved to dump1.png file."); Out.Ln;
END LoadMemIO;


(** load an image, save to memory, then, acquire it save its data to file *)
PROCEDURE AcquireMemIO*(context: Commands.Context);
VAR fname: ARRAY 128 OF CHAR;

	tdib: FI.FIBITMAP;
	fif: FI.IMAGE_FORMAT;
	hmem: FI.FIMEMORY;
	res: BOOLEAN;

	f: Files.File;
	wr: Files.Rider;
	membufptr: ADDRESS;
	i, bufsize: SIGNED32;
	ch: CHAR;

BEGIN
	
	IF ~context.arg.GetString(fname) THEN RETURN END;
	
	fif := FI.GetFileType(fname,0);	
	tdib := FI.Load(fif, fname,0);

	IF tdib = NIL THEN
		Out.String(fname); Out.String(": Image NOT Loaded .."); Out.Ln();
		RETURN;
	END;

	(* open a memory handle *)
	hmem := FI.OpenMemory(0, 0);

	(* save the file to memory *)
	res := FI.SaveToMemory(fif, tdib, hmem, 0);
	FI.Unload(tdib);
	
	bufsize := 0;
	membufptr := NIL;
	res := FI.AcquireMemory(hmem, membufptr, bufsize);
	
	IF membufptr = NIL THEN
		Out.String("membuf=NIL "); Out.Ln;
		FI.CloseMemory(hmem);
		RETURN
	ELSE
		Out.String("membuf # NIL"); Out.Ln;
	END;
	Out.String("bufsize (bytes): "); Out.Int(bufsize, 0); Out.Ln;
	
	(* save the buffer in a file stream *)
	f := Files.New("buffer1.png");
	f.Set(wr, 0);
	i := 0;
	WHILE i < bufsize DO
		S.GET(membufptr,ch);
		f.Write(wr,ch);
		INC(i);
		INC(membufptr);
	END;
	f.Update();	 
	Files.Register(f);

	FI.CloseMemory(hmem);
	Out.String("AcquireMemIO finished, saved to buffer1.png file."); Out.Ln;
END AcquireMemIO;

BEGIN

END TestFreeMemIO.



TestFreeMemIO.SaveMemIO Lennagray.png ~


TestFreeMemIO.LoadMemIO   Lennagray.png ~

TestFreeMemIO.AcquireMemIO  Lennagray.png~


System.Free TestFreeMemIO  ~

System.FreeDownTo FreeImageDll ~ 
