MODULE antsCaches IN Oberon;  (** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to ants@AntsInFields.de
*)




IMPORT Out,aM := antsMessages;
CONST debug = FALSE;
TYPE
	Function* = PROCEDURE (VAR A: ARRAY OF SIGNED16): FLOAT64;

	FullCache* = OBJECT (* POINTER TO FullCacheDesc;
	FullCacheDesc* = RECORD
	*)
	VAR
		values*: POINTER TO ARRAY OF FLOAT64;
		offset: POINTER TO ARRAY  OF SIGNED32;
		len-: POINTER TO ARRAY OF SIGNED32;
		d-, size-: SIGNED32;

		PROCEDURE (*c: FullCache*) Offset* (VAR point: ARRAY OF SIGNED16;  level: SIGNED32): SIGNED32;
	VAR i: SIGNED32;  offset: SIGNED32;
BEGIN
	offset := 0;  FOR i := level TO SELF.d - 1 DO INC(offset, point[i] *  SELF.offset[i]) END;
	RETURN offset
END Offset;

PROCEDURE (*c: FullCache*) Point* (offset: SIGNED32;  VAR point: ARRAY OF SIGNED16);
	VAR i: SIGNED32;
BEGIN
	FOR i := SELF.d - 1 TO 0 BY - 1 DO point [i] := SHORT(offset DIV SELF.offset[i]);   offset := offset MOD SELF.offset[i]  END
END Point;
PROCEDURE (*c: FullCache*) NextPoint* (VAR offset: SIGNED32;  VAR point: ARRAY OF SIGNED16;  level: SIGNED32): BOOLEAN;
	(* move to next point, INC offset and point values, offset=-1 initializes to 0 *)
	VAR i: SIGNED32;
BEGIN
	IF offset = - 1 THEN FOR i := 0 TO SELF.d - 1 DO point[i] := 0 END;  offset := 0;  RETURN TRUE END;
	i := level;
	INC(offset, SELF.offset[i]);  IF offset >= SELF.size THEN RETURN FALSE END;
	INC(point[i]);
	WHILE (point[i] = SELF.len[i]) DO
		point[i] := 0;
		INC(i);  INC(point[i])
	END;
	RETURN TRUE
END NextPoint;
PROCEDURE (*c: FullCache*) SetVal* (offset: SIGNED32;  val: FLOAT64);
BEGIN
	SELF.values[offset] := val
END SetVal;

PROCEDURE (*c: FullCache*) GetVal* (offset: SIGNED32): FLOAT64;
BEGIN
	RETURN SELF.values[offset]
END GetVal;

	END FullCache;

	(* FullCache: Caches matrices of dimensions >>2,

	1.) setvalue at pos vector (a0,a1,..,a(dim-1)) = FLOAT64
	2.) getvalue at pos vector (a0,a1,...a(dim-1)) = FLOAT64
	3.) getvalvec at pos vector (a0,a1,...,a(dim-2)) = ARRAY OF FLOAT64;

	=> d-dimensional box with lengths len.

	*)
	VAR enabled: BOOLEAN;


PROCEDURE Create (c: FullCache;   d: SIGNED32);
	VAR i: SIGNED32;
BEGIN
	c.d := d;
	NEW(c.len, d);  FOR i := 0 TO d - 1 DO c.len[i] := 0 END;
	NEW(c.offset, d);  FOR i := 0 TO d - 1 DO c.offset[i] := 0 END
END Create;

PROCEDURE Cuboid* (d: SIGNED32;  VAR len: ARRAY OF SIGNED16;  maxsize: SIGNED32): FullCache;
	VAR i: SIGNED32;  offset: SIGNED32;  c: FullCache;
BEGIN
	IF ~enabled THEN RETURN NIL END;
	NEW(c);
	Create(c, d);
	FOR i := 0 TO d - 1 DO c.len[i] := len[i]  END;
	offset := 1;
	FOR i := 0 TO d - 1 DO c.offset[i] := offset;  offset := offset * LONG(len[i]);  IF debug THEN Out.Int(offset, 10);  Out.Ln()   END;
		IF offset > maxsize THEN RETURN NIL END
	END;
	c.size := offset;
	IF c.size <= maxsize THEN
		aM.vSI("antsCaches: creating a cache with size, this can be a lengthy operation.",c.size);
		NEW(c.values, c.size);
		aM.vS("antsCaches: done.");
		IF debug THEN
			Out.String("antsCaches: Created Cache of Size");  Out.Int(c.size, 10);  Out.Ln();
			Out.String("c.d");  Out.Int(c.d, 10);  Out.Ln()
		END;
		RETURN c
	ELSE RETURN NIL END
END Cuboid;

PROCEDURE  Cube* (d: SIGNED32;  len: SIGNED16;  maxsize: SIGNED32): FullCache;
	VAR lenA: POINTER TO ARRAY OF SIGNED16;  i: SIGNED32;
BEGIN
	IF debug THEN
		Out.String("Trying Cache .. ");  Out.Int(d, 20);  Out.Int(len, 20);  Out.Ln()
	END;
	NEW(lenA, d);
	FOR i := 0 TO d - 1 DO lenA[i] := len END;
	RETURN Cuboid(d, lenA^, maxsize)
END Cube;



PROCEDURE Disable*;
BEGIN
	enabled := FALSE;
	aM.S("Caching disabled");
END Disable;

PROCEDURE Enable*;
BEGIN
	enabled := TRUE;
	aM.S("Caching enabled");
END Enable;

PROCEDURE Test*;
	VAR c: FullCache; i: SIGNED32;   len: ARRAY 5 OF SIGNED16;  offset: SIGNED32;
BEGIN
	c := Cube(5, 3, 10000);
	IF c # NIL THEN
		Out.String("Success")
	ELSE Out.String("No Success");  RETURN
	END;
	Out.Ln();
	Out.String("dim");  Out.Int(c.d, 10);  Out.Ln();
	Out.String("size");  Out.Int(c.size, 10);  Out.Ln();
	FOR i := 0 TO c.d - 1 DO
		Out.String("len[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(c.len[i], 10);  Out.Ln();
		Out.String("off[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(c.offset[i], 10);  Out.Ln()
	END;

	NEW(c);
	len[0] := 10;  len[1] := 5;  len[2] := 5;  len[3] := 3;  len[4] := 2;
	c := Cuboid(5, len, 10000);
	IF c # NIL THEN
		Out.String("Success")
	ELSE Out.String("No Success");  RETURN
	END;
	Out.Ln();
	Out.String("dim");  Out.Int(c.d, 10);  Out.Ln();
	Out.String("size");  Out.Int(c.size, 10);  Out.Ln();
	FOR i := 0 TO c.d - 1 DO
		Out.String("len[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(c.len[i], 10);  Out.Ln();
		Out.String("off[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(c.offset[i], 10);  Out.Ln()
	END;

	len[0] := 9;  len[1] := 2;  len[2] := 3;  len[3] := 2;  len[4] := 1;
	FOR i := 0 TO c.d - 1 DO
		Out.String("point[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(len[i], 10);  Out.Ln()
	END;
	offset := c.Offset(len, 0);
	Out.String("offset");  Out.Int(offset, 10);  Out.Ln();
	len[0] := 0;  len[1] := 0;  len[2] := 0;  len[3] := 0;  len[4] := 0;
	c.Point(offset, len);
	FOR i := 0 TO c.d - 1 DO
		Out.String("point[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(len[i], 10);  Out.Ln()
	END;
	WHILE c.NextPoint(offset, len, 0) DO
		Out.String("next");  Out.Ln();
		Out.String("offset");  Out.Int(offset, 10);  Out.Ln();
		c.SetVal(offset, offset - 200);
		Out.String("val");  Out.LongReal(c.GetVal(offset), 30);  Out.Ln();
		FOR i := 0 TO c.d - 1 DO
			Out.String("point[");  Out.Int(i, 0);  Out.String("] =");  Out. Int(len[i], 10);  Out.Ln()
		END
	END

END Test;



BEGIN
	aM.launch;
	Enable;
END antsCaches.

antsCaches.Test ~


(*
PROCEDURE makeoffsets (c: FullCache);
VAR l,i: SIGNED32;
BEGIN
NEW(c.dimensionOffset,c.dimensions);
l := 1;
FOR i := 0 TO c.dimensions-1 DO c.dimensionOffset[i] := l; l := l*c.size END;
END makeoffsets;

PROCEDURE len (size: SIGNED32; dimension: SIGNED32): SIGNED32;
VAR i,l: SIGNED32;
BEGIN
l := 1;  FOR i :=0 TO dimension-1 DO l := l*size END;
RETURN l;
END len;

PROCEDURE pos0 (VAR c: FullCache; VAR A: ARRAY OF SIGNED16): SIGNED32;
VAR i: SIGNED32; l: SIGNED32; size: SIGNED32; bv: SIGNED32;
BEGIN
l := 0; size := c.size; bv := c.dimensions-1;
FOR i := 1 TO bv DO
INC(l,A[i]*(* c.dimensionOffset[i]*) size); size := size * c.size;
END;
RETURN l;
END pos0;

PROCEDURE (c: FullCache) next* (VAR A: ARRAY OF SIGNED16): BOOLEAN;
	VAR i: SIGNED16;
BEGIN
	i := 0; WHILE( i < c.dimensions) DO
		INC(A[i]);
		IF A[i] = c.size THEN A[i] := 0
		ELSE RETURN TRUE
		END;
		INC(i)
	END;
	RETURN FALSE
END next;

PROCEDURE CreateFullCache* (dimensions, size: SIGNED32; maxsize: SIGNED32): FullCache;
	VAR c: FullCache; l: SIGNED32; i: SIGNED32;
BEGIN
	l := len(size, dimensions);
	IF size * SIZEOF(FLOAT64) > maxsize THEN
		vyHostTexts.NoteSI(vyHostTexts.cNotify, "Building no cache, size would be", size * l * SIZEOF(FLOAT64));
		RETURN NIL
	ELSE
		NEW(c);
		NEW(c.vals, l);
		FOR i := 0 TO l - 1 DO  c.vals[i] := MAX(FLOAT64) END;
		c.size := size;
		c.dimensions := dimensions;
		makeoffsets(c);
		RETURN c
	END
END CreateFullCache;

PROCEDURE  (c: FullCache )  cachedArrayAddr* (VAR m: antsMasks.Mask): SIGNED32;
	VAR offset: SIGNED32;
BEGIN
	(* offset := ADDRESSOF(c.vals^); *)
	offset := 0;
	m.baseNPos(c.size, offset);
	RETURN offset
END cachedArrayAddr;

PROCEDURE (c: FullCache)  cacheArray* ( VAR v: ARRAY OF SIGNED16; VAR A: ARRAY OF FLOAT64);
	VAR i: SIGNED32; pos, mv: SIGNED32;
BEGIN
	pos := pos0(c, v); mv := c.size - 1;
	FOR i := 0 TO mv DO c.vals[pos + i] := A[i] END
END cacheArray;

PROCEDURE Test*;
	VAR c: FullCache; i: SIGNED32;  len: ARRAY 5 OF SIGNED32; offset: SIGNED32;
BEGIN
	NEW(c);
	IF c.Cube(5, 3, 10000) THEN
		Out.String("Success")
	ELSE Out.String("No Success")
	END;
	Out.Ln();
	Out.String("dim"); Out.Int(c.d, 10); Out.Ln();
	Out.String("size"); Out.Int(c.size, 10); Out.Ln();
	FOR i := 0 TO c.d - 1 DO
		Out.String("len["); Out.Int(i, 0); Out.String("] ="); Out. Int(c.len[i], 10); Out.Ln();
		Out.String("off["); Out.Int(i, 0); Out.String("] ="); Out. Int(c.offset[i], 10); Out.Ln()
	END;

	NEW(c);
	len[0] := 10; len[1] := 5; len[2] := 5; len[3] := 3; len[4] := 2;
	IF c.Cuboid(5, len, 10000) THEN
		Out.String("Success")
	ELSE Out.String("No Success")
	END;
	Out.Ln();
	Out.String("dim"); Out.Int(c.d, 10); Out.Ln();
	Out.String("size"); Out.Int(c.size, 10); Out.Ln();
	FOR i := 0 TO c.d - 1 DO
		Out.String("len["); Out.Int(i, 0); Out.String("] ="); Out. Int(c.len[i], 10); Out.Ln();
		Out.String("off["); Out.Int(i, 0); Out.String("] ="); Out. Int(c.offset[i], 10); Out.Ln()
	END;

	len[0] := 9; len[1] := 2; len[2] := 3; len[3] := 2; len[4] := 1;
	FOR i := 0 TO c.d - 1 DO
		Out.String("point["); Out.Int(i, 0); Out.String("] ="); Out. Int(len[i], 10); Out.Ln()
	END;
	offset := c.Offset(len);
	Out.String("offset"); Out.Int(offset, 10); Out.Ln();
	len[0] := 0; len[1] := 0; len[2] := 0; len[3] := 0; len[4] := 0;
	c.Point(offset, len);
	FOR i := 0 TO c.d - 1 DO
		Out.String("point["); Out.Int(i, 0); Out.String("] ="); Out. Int(len[i], 10); Out.Ln()
	END;
	WHILE c.NextPoint(offset, len) DO
		Out.String("next"); Out.Ln();
		Out.String("offset"); Out.Int(offset, 10); Out.Ln();
		c.SetVal(offset, offset - 200);
		Out.String("val"); Out.LongReal(c.GetVal(offset), 30); Out.Ln();
		FOR i := 0 TO c.d - 1 DO
			Out.String("point["); Out.Int(i, 0); Out.String("] ="); Out. Int(len[i], 10); Out.Ln()
		END
	END

END Test;
 * )

