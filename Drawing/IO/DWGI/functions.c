// function.c 

// This file is part of the CAD::Drawing::IO::DWGI package Copyright
// 2003 Eric Wilhelm and A. Zahner Co.  This Perl module is free
// software, made available AS-IS and distributed under the same terms
// as Perl.  See the main module file (DWGI.pm) for details.
//
// This is a set of functions which wrap the OpenDWG toolkit so that it
// can be called from Perl programs.  There is no connection between the
// licensing of this software and the licensing of the OpenDWG toolkit.
// You must obtain and install the toolkit under the licensing terms of
// the OpenDWG consortium in order to use this module, as their
// licensing prohibits distribution of the library and header files
// (though they are free to use if you join the Consortium as an
// Associate (or higher) member.)
//
// See http://www.opendwg.org for details.
//
// While the Author and his employer are Associate members of the
// OpenDWG consortium for purposes of using the OpenDWG libraries, this
// is the full extent of their relationship.
//
// By using this software, you agree to not hold any party liable for
// anything which your use of this software causes to happen to you,
// your dog, your business, or anything else.  You also agree that no
// entity or person is responsible for anything that any other entity or
// person has caused to happen and that anything which you do (including
// using this software and obtaining the appropriate license and
// libraries for it) is YOUR OWN RESPONSIBILITY.


#define AD_PROTOTYPES
#include "ad2.h"
#define OD_GENERIC_READ
#include "odio.h"



typedef struct {
	PAD_DWGHDR   adhd;
	PAD_ENT_HDR  adenhd;
	PAD_ENT      aden;
	PAD_TB       adtb;
	PAD_XD       adxd;
	AD_OBJHANDLE default_ltype; // default linetype handle
	AD_OBJHANDLE default_layer; // default layer handle
	AD_OBJHANDLE current_layer; // current layer handle
	AD_VMADDR    entitylist;
	AD_DB_HANDLE handle;
	bool         file_is_open;
	short        version;
} DWGstruct;

const char initfilepath[]="/usr/lib/perl5/site_perl/5.6.1/Zahner/adinit.dat";
short initerror;

short criterrhandler(short num);
int allocateadptrs(DWGstruct* dwg);
/*-------------------------Greeting-----------------------------------*/
void hello() {
	printf("hello world\n");
	}

/*-------------------------CONSTRUCTOR--------------------------------*/
SV*	new (char* class) {
	DWGstruct* dwg = malloc(sizeof(DWGstruct));
	SV*        obj_ref = newSViv(0);
	SV*        obj = newSVrv(obj_ref, class); // creates the blessed reference
	//adSetAd2CriticalErrorFn(criterrhandler);
	if(!adInitAd2(initfilepath,&initerror)) {
		printf("failing miserably\n");
		return(&PL_sv_undef);
		}
	if(!allocateadptrs(dwg))
		return(&PL_sv_undef);
	sv_setiv(obj, (IV)dwg);
	SvREADONLY_on(obj);
	return(obj_ref);
	};

/*-------------------------LOAD FILE----------------------------------*/
int loadfile(SV* obj, char* infile) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	adSetupDwgRead();
	adSetupDxfRead();
	//printf("loading file\n");
	if(dwg->handle = adLoadFile(infile,AD_PRELOAD_ALL,1)) {
		//printf("loaded okay\n");
		dwg->file_is_open = 1;
		return(1);
		}
	croak("loading failed miserably\n");
	return(0);
	}
/*-------------------------listlayers---------------------------------*/
void listlayers(SV* obj) {
	Inline_Stack_Vars;
	long num;
	long i;
	long len;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	PAD_TB adtb = dwg->adtb;
	Inline_Stack_Reset;
	adStartLayerGet(dwg->handle);
	num = adNumLayers(dwg->handle);
	for(i=0;i<num;i++) {
		SV* tmpsv;
		adGetLayer(dwg->handle, &adtb->lay);
		if(! adtb->lay.purgedflag) {
			//printf("\tshould see %s\n", adtb->lay.name);
			len = strlen(adtb->lay.name);
			tmpsv = newSVpvn(adtb->lay.name, len);
			Inline_Stack_Push(sv_2mortal(tmpsv));
			}
		}
	Inline_Stack_Done;		
	}
/*-------------------------New File-----------------------------------*/
int newfile(SV* obj, short version) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	AD_LTYPE templtp;
	dwg->handle = adNewFile(NULL, NULL, 0, version);
	dwg->adhd = adHeaderPointer(dwg->handle);
	dwg->adhd->dwgcodepage = 30;  // get rid of NLS error
	adFindLayerByName(dwg->handle, "0", dwg->default_layer);
	adHancpy(dwg->current_layer, dwg->default_layer);
	adStartLinetypeGet(dwg->handle);
	adGetLinetype( dwg->handle, &templtp);
	adHancpy(dwg->default_ltype, templtp.objhandle);
	dwg->version = version;
	dwg->file_is_open = 1;
	}
/*-------------------------Save File----------------------------------*/
short savefile(SV* obj, char* filename, short filetype) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	short dxfnegz= 0;
	short dxfdecprec= 6;
	short dxfwritezeroes = 1;
	char r12dxfvbls= 1;
	if( filetype != AD_DWG) {
		// setup options for dxf write
		dxfnegz= 1;
		dxfdecprec = 14;
		dxfwritezeroes = 1;
		r12dxfvbls= 1; // not writing R11 DXF
		}
	adSaveFile (dwg->handle, filename, (char) filetype, dwg->version, 
					dxfnegz, dxfdecprec, dxfwritezeroes, r12dxfvbls);
	}
/*-------------------------getCircle----------------------------------*/	
SV* getCircle(SV* obj) {
	AV * pt;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	//printf("circle at: %3.2f,%3.2f\n", dwg->aden->circle.pt0[0], dwg->aden->circle.pt0[1]);
	hv_store(hash, "pt", 2, newRV_noinc((SV*)pt = newAV()), 0);
	av_push(pt, newSVnv(dwg->aden->circle.pt0[0]));
	av_push(pt, newSVnv(dwg->aden->circle.pt0[1]));
	av_push(pt, newSVnv(dwg->aden->circle.pt0[2]));
	hv_store(hash, "rad", 3, newSVnv(dwg->aden->circle.radius), 0);
	return(newRV_noinc((SV*) hash));
	}
/*--------------------------------------------------------------------*/
int writeCircle(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	SV** psv;
	SV** psv2;
	SV* val;
	int i;
	I32 len;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = AD_ENT_CIRCLE;
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	// printf("writing circle\n");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pt", 2)) {
		psv = hv_fetch(hash, "pt", 2, 0);
		val = *psv;
		pt = (AV*)SvRV(val);
		len = av_len(pt);
		//printf("array length: %d\n", len);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv2 = av_fetch(pt, i, 0);
				val = *psv2;
				dwg->aden->circle.pt0[i] = SvNV(val);
				//printf("point %d:  %4.2f\n", i, dwg->aden->circle.pt0[i]);
				}
			else {
				dwg->aden->circle.pt0[i] = 0;
				}
			}
		}
	else {
		croak("no pt passed");
		}
	if(hv_exists(hash, "rad", 3)) {
		//printf("fetching\n");
		psv = hv_fetch(hash, "rad", 3,0);
		//printf("deref\n");
		val = *psv;
		//printf("setting\n");
		if(!SvNOK(val))
			croak("not a double");
		dwg->aden->circle.radius = SvNV(val);
		//printf("set radius to %3.2f\n", dwg->aden->circle.radius);
		}
	else {
		croak("no  rad passed");
		}
	// to set circle direction, use dwg->adenhd->extrusion[0], [1], and [2]
	if(hv_exists(hash, "extrusion", 9)) {
		psv = hv_fetch(hash, "extrusion", 9, 0);
		val = *psv;
		printf("fixme: trying to set extrusion direction\n");
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	//printf("copy ok\n");
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	}

	
/*-------------------------getArc-------------------------------------*/	
SV* getArc(SV* obj) {
	AV * pt;
	AV * angs;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	hv_store(hash, "pt", 2, newRV_noinc((SV*)pt = newAV()), 0);
	av_push(pt, newSVnv(dwg->aden->arc.pt0[0]));
	av_push(pt, newSVnv(dwg->aden->arc.pt0[1]));
	av_push(pt, newSVnv(dwg->aden->arc.pt0[2]));
	hv_store(hash, "rad", 3, newSVnv(dwg->aden->arc.radius), 0);
	hv_store(hash, "angs", 4, newRV_noinc((SV*)angs = newAV()), 0);
	av_push(angs, newSVnv(dwg->aden->arc.stang));
	av_push(angs, newSVnv(dwg->aden->arc.endang));
	return(newRV_noinc((SV*) hash));
	}
/*--------------------------------------------------------------------*/
int writeArc(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	AV* angs;
	SV** psv;
	SV* val;
	int i;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = AD_ENT_ARC;
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pt", 2)) {
		psv = hv_fetch(hash, "pt", 2, 0);
		val = *psv;
		pt = (AV*)SvRV(val);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
				dwg->aden->arc.pt0[i] = SvNV(val);
				}
			else {
				dwg->aden->arc.pt0[i] = 0;
				}
			}
		}
	else {
		croak("no pt passed");
		}
	if(hv_exists(hash, "rad", 3)) {
		psv = hv_fetch(hash, "rad", 3,0);
		val = *psv;
		if(!SvNOK(val))
			croak("not a double");
		dwg->aden->arc.radius = SvNV(val);
		}
	else {
		croak("no  rad passed");
		}
	if(hv_exists(hash, "angs", 4)) {
		psv = hv_fetch(hash, "angs", 4, 0);
		val = *psv;
		if(!SvROK(val))
			croak("angs not a reference");
		angs = (AV*)SvRV(val);
		psv = av_fetch(angs, 0, 0);
		val = *psv;
		dwg->aden->arc.stang = SvNV(val);
		psv = av_fetch(angs, 1, 0);
		val = *psv;
		dwg->aden->arc.endang = SvNV(val);
		}
	else {
		croak("no angs passed");
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
			
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	}


	
/*-------------------------getLine------------------------------------*/	
SV* getLine(SV* obj) {
	int i;
	AV * pts;
	AV * pt0;
	AV * pt1;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	hv_store(hash, "pts", 3, newRV_noinc((SV*)pts = newAV()), 0);
	av_push(pts, newRV_noinc((SV*)pt0 = newAV()));
	av_push(pts, newRV_noinc((SV*)pt1 = newAV()));
	for(i=0;i<2;i++) {
		av_push(pt0, newSVnv(dwg->aden->line.pt0[i]));
		}
	for(i=0;i<2;i++) {
		av_push(pt1, newSVnv(dwg->aden->line.pt1[i]));
		}
	return(newRV_noinc((SV*) hash));
	}
/*--------------------------------------------------------------------*/
int writeLine(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	AV* pts;
	SV** psv;
	SV* val;
	int i;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = AD_ENT_LINE;
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pts", 3)) {
		psv = hv_fetch(hash, "pts", 3, 0);
		val = *psv;
		if(!SvROK(val))
			croak("pts not a reference");
		pts = (AV*)SvRV(val);
		psv = av_fetch(pts, 0, 0);
		val = *psv;
		if(!SvROK(val))
			croak("pt not a reference");
		pt = (AV*)SvRV(val);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
				dwg->aden->line.pt0[i] = SvNV(val);
				}
			else {
				dwg->aden->line.pt0[i] = 0;
				}
			}
		psv = av_fetch(pts, 1, 0);
		val = *psv;
		if(!SvROK(val))
			croak("pt not a reference");
		pt = (AV*)SvRV(val);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
				dwg->aden->line.pt1[i] = SvNV(val);
				}
			else {
				dwg->aden->line.pt1[i] = 0;
				}
			}
		} // end if "pts" key
	else {
		croak("pts not passed");
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
			
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	} 
/*-------------------------getText------------------------------------*/	
SV* getText(SV* obj) {
	int i;
	long len;
	AV * pt;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	hv_store(hash, "pt", 2, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<2;i++) {
		av_push(pt, newSVnv(dwg->aden->text.pt0[i]));
		}
	len = strlen(dwg->aden->text.textstr);
	hv_store(hash, "string", 6, newSVpvn(dwg->aden->text.textstr, len), 0);
	// now for the long-awaited text height!
	hv_store(hash, "height", 6, newSVnv(dwg->aden->text.tdata.height), 0);
	return(newRV_noinc((SV*) hash));
	}
/*--------------------------------------------------------------------*/
int writeText(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	SV** psv;
	SV* val;
	int i;
	STRLEN len;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = AD_ENT_TEXT;
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pt", 2)) {
		psv = hv_fetch(hash, "pt", 2, 0);
		val = *psv;
		pt = (AV*)SvRV(val);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
				dwg->aden->text.pt0[i] = SvNV(val);
				}
			else {
				dwg->aden->text.pt0[i] = 0;
				}
			}
		}
	else {
		croak("no pt passed");
		}
	if(hv_exists(hash, "string", 6)) {
		psv = hv_fetch(hash, "string", 6, 0);
		val = *psv;
		len = SvLEN(val);
		strcpy(dwg->aden->text.textstr, SvPV(val, len));
		}
	else {
		croak("no string passed");
		}
	if(hv_exists(hash, "height", 6)) {
		psv = hv_fetch(hash, "height", 6, 0);
		val = *psv;
		dwg->aden->text.tdata.height = SvNV(val);
		}
	else {
		// let a default height be used
		dwg->aden->text.tdata.height = 1;
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
			
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	} // end writeText
	
/*-------------------------getPoint-----------------------------------*/	
SV* getPoint(SV* obj) {
	int i;
	AV * pt;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	hv_store(hash, "pt", 2, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<2;i++) {
		av_push(pt, newSVnv(dwg->aden->point.pt0[i]));
		}
	return(newRV_noinc((SV*) hash));
	}
/*--------------------------------------------------------------------*/
int writePoint(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	SV** psv;
	SV* val;
	int i;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = AD_ENT_POINT;
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pt", 2)) {
		psv = hv_fetch(hash, "pt", 2, 0);
		val = *psv;
		pt = (AV*)SvRV(val);
		for(i=0;i<3;i++) {
			if(av_exists(pt, i)) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
				dwg->aden->point.pt0[i] = SvNV(val);
				}
			else {
				dwg->aden->point.pt0[i] = 0;
				}
			}
		}
	else {
		croak("no pt passed");
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
			
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	}

	
/*--------------------------------------------------------------------*/	
SV* getLWPline(SV* obj) {
	PAD_BLOB_CTRL bcptr;
	OdaLong il;
	long num;
	double tempdouble[2];
	double tempbulge;
	double tempwidth[2];
	AV * pts;
	AV * pt;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	num = (long) dwg->aden->lwpline.numpoints;
	bcptr = adStartBlobRead(dwg->aden->lwpline.ldblob);
	hv_store(hash, "pts", 3, newRV_noinc((SV*)pts = newAV()), 0);
	for(il=0;il < num; il++) {
		adReadBlob2Double(bcptr, tempdouble);
		if(dwg->aden->lwpline.flag & AD_LWPLINE_HAS_BULGES) {
			adReadBlobDouble(bcptr, &tempbulge);
		}
		if (dwg->aden->lwpline.flag & AD_LWPLINE_HAS_WIDTHS) {
			adReadBlob2Double(bcptr,tempwidth);
		}
		//printf("points: %3.2f,%3.2f\n", tempdouble[0], tempdouble[1]);
		av_push(pts, newRV_noinc((SV*)pt = newAV()));
		av_push(pt, newSVnv(tempdouble[0]));
		av_push(pt, newSVnv(tempdouble[1]));
	}
	if(dwg->aden->lwpline.flag & AD_LWPLINE_IS_CLOSED) {
		hv_store(hash, "closed", 6, newSViv(1), 0);
	}
	// FIXME: this should go under getent?
	if(adEntHasExtrusion(dwg->adenhd->entflags)) {
		printf("has extrusion\n");
	}
	return(newRV_noinc((SV*) hash));
}
/*--------------------------------------------------------------------*/	
int writeLWPline(SV* obj, SV* args) {
	HV* hash;
	AV* pt;
	AV* pts;
	SV** psv;
	SV* val;
	int i;
	I32 p;
	I32 num;
	double point[2];
	PAD_BLOB_CTRL bcptr;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	dwg->adenhd->enttype = adLwplineEnttype(dwg->handle);
	adSetEntityDefaults( dwg->handle, dwg->adenhd, dwg->aden);
	adGenerateObjhandle(dwg->handle, dwg->adenhd->enthandle);
	if(! SvROK(args))
		croak("args is not a reference");
	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "pts", 3)) {
		dwg->aden->lwpline.ldblob = adCreateBlob();
		bcptr = adStartBlobWrite(dwg->aden->lwpline.ldblob);
		psv = hv_fetch(hash, "pts", 3, 0);
		val = *psv;
		if(!SvROK(val))
			croak("pts not a reference");
		pts = (AV*)SvRV(val);
		num = av_len(pts);
		dwg->aden->lwpline.numpoints = (long) num + 1;
	//	printf("lwpline with %d points\n", num+1);
		for(p = 0; p <= num; p++) {
			psv = av_fetch(pts, p, 0);
			val = *psv;
			if(!SvROK(val))
				croak("point is not a reference");
			pt = (AV*)SvRV(val);
			for(i = 0; i < 2;i++) {
				psv = av_fetch(pt, i, 0);
				val = *psv;
			//	printf("adding point %d #%d\n", p, i);
				point[i] = SvNV(val);
				}
			adWriteBlobBytes(bcptr, point, 2 *sizeof(double) );
			}
		adEndBlobWrite(bcptr);
		}
	else {
		croak("pts not passed");
		}
	if(hv_exists(hash, "closed", 6)) {
		psv = hv_fetch(hash, "closed", 6, 0);
		val = *psv;
		if(sv_true(val)) {
			dwg->aden->lwpline.flag |= AD_LWPLINE_IS_CLOSED;
			}
		}
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color", 5, 0);
		val = *psv;
		dwg->adenhd->entcolor = SvIV(val);
		}
	else {
		dwg->adenhd->entcolor = AD_COLOR_BYLAYER;
		}
	adHancpy(dwg->adenhd->entlayerobjhandle, dwg->current_layer);
	adAddEntityToList( dwg->handle, dwg->entitylist, dwg->adenhd, dwg->aden);
	} 


/*--------------------------------------------------------------------*/	
SV* getImage(SV* obj) {
	PAD_BLOB_CTRL bcptr;
	int i;
	long il;
	long len;
	double tempdouble[2];
	AD_OBJHANDLE defhandle;
	AD_OBJ_HDR adobhd;
	AD_OBJ adob;
	long num;
	AV * cpts;
	AV * pt;
	HV * hash = newHV();
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	hv_store(hash, "pt", 2, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<2;i++) {
		av_push(pt, newSVnv(dwg->aden->image.pt0[i]));
		}
	hv_store(hash, "size", 4, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<1;i++) {
		av_push(pt, newSVnv(dwg->aden->image.size[i]));
		}
	hv_store(hash, "uvec", 4, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<2;i++) {
		av_push(pt, newSVnv(dwg->aden->image.uvec[i]));
		}
	hv_store(hash, "vvec", 4, newRV_noinc((SV*)pt = newAV()), 0);
	for(i=0;i<2;i++) {
		av_push(pt, newSVnv(dwg->aden->image.vvec[i]));
		}
	// check for clipping
	if(dwg->aden->image.clipping == 1) {
		hv_store(hash, "clipping", 8, newRV_noinc((SV*)cpts = newAV()), 0);
		num = dwg->aden->image.numclipverts;
		if(num == 2) {
			av_push(cpts, newRV_noinc((SV*)pt = newAV()));
			av_push(pt, newSVnv(dwg->aden->image.rectclipvert0[0]));
			av_push(pt, newSVnv(dwg->aden->image.rectclipvert0[1]));
			av_push(cpts, newRV_noinc((SV*)pt = newAV()));
			av_push(pt, newSVnv(dwg->aden->image.rectclipvert1[0]));
			av_push(pt, newSVnv(dwg->aden->image.rectclipvert1[1]));
			}
		else {
			bcptr=adStartBlobRead(dwg->aden->image.polyclipvertblob);
			for( il = 0; il < num; il++) {
				adReadBlob2Double(bcptr,tempdouble);
				av_push(cpts, newRV_noinc((SV*)pt = newAV()));
				av_push(pt, newSVnv(tempdouble[0]));
				av_push(pt, newSVnv(tempdouble[1]));
				}
			}
		} // end if clipping
	adSeekObject(dwg->handle, dwg->aden->image.imagedefobjhandle, &adobhd, &adob);
	len = strlen(adob.imagedef.filepath);
	hv_store(hash, "fullpath", 8, newSVpvn(adob.imagedef.filepath, len), 0);
	return(newRV_noinc((SV*) hash));
	}
/*-------------------------Setup Entity Get---------------------------*/
int getentinit(SV* obj) {
	AD_OBJHANDLE mspaceblkobjhandle;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	// FIXME: this is trapped in modelspace land!
	adGetBlockHandle(dwg->handle, mspaceblkobjhandle, AD_MODELSPACE_HANDLE);
	dwg->entitylist = adEntityList(dwg->handle, mspaceblkobjhandle);
	adStartEntityGet(dwg->entitylist); // rewinds the entitylist
	}
/*-------------------------Single Entity Get--------------------------*/
void getent(SV* obj) {
	Inline_Stack_Vars;
	AD_LAY layer;
	long len;
	char * type;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	PAD_ENT_HDR  adenhd = dwg->adenhd;
	Inline_Stack_Reset;
	if (!( adGetEntity(dwg->entitylist, adenhd, dwg->aden) ) ) {
		Inline_Stack_Done;		
		return;
		}
	adSeekLayer(dwg->handle, adenhd->entlayerobjhandle, &layer);
	len = strlen(layer.name);
	Inline_Stack_Push(sv_2mortal(newSVpvn(layer.name, len)));
	Inline_Stack_Push(sv_2mortal(newSViv(adenhd->entcolor)));
	Inline_Stack_Push(sv_2mortal(newSViv(adenhd->enttype)));
	Inline_Stack_Done;
	}
/*--------------------------------------------------------------------*/
int writeLayer(SV* obj, SV* args) {
	short color;
	char * name;
	SV** psv;
	SV* val;
	STRLEN len;
	HV* hash;
	HE* entry;
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));

	if(! SvROK(args))
		croak("args is not a reference");

	hash = (HV*)SvRV(args);
	if(hv_exists(hash, "name", 4)) {
		psv = hv_fetch(hash, "name", 4, 0);
		val = *psv;
		len = SvLEN(val);
		name = SvPV(val, len);
		}
	else {
		croak("layer name is required");
		}
	adSetDefaultLayer(dwg->handle, &dwg->adtb->lay);
	strcpy(dwg->adtb->lay.name, name);
	if(hv_exists(hash, "color", 5)) {
		psv = hv_fetch(hash, "color",  5, 0);
		val = *psv;
		color = SvIV(val);
		}
	else {
		color = AD_COLOR_WHITE;
		}
	dwg->adtb->lay.color = color;
	// need to add support  for more linetypes later
	adHancpy(dwg->adtb->lay.linetypeobjhandle, dwg->default_ltype);
	adGenerateObjhandle(dwg->handle,dwg->adtb->lay.objhandle);
	// set the current layer handle to this layer
	adHancpy(dwg->current_layer, dwg->adtb->lay.objhandle);
	adAddLayer(dwg->handle,&dwg->adtb->lay);
	}
/*--------------------------------------------------------------------*/
int setLayer(SV * obj, char * name) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	if(adFindLayerByName(dwg->handle, name, dwg->current_layer));
		return(1);
	return(0);
	}
/*-------------------------Constants Lookup---------------------------*/
char* entype(SV* obj, int type) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	switch (type) {
		case AD_ENT_LINE:
			return("lines");
		case AD_ENT_POINT:
			return("points");
		case AD_ENT_CIRCLE:
			return("circles");
		case AD_ENT_TEXT:
			return("texts");
		case AD_ENT_ARC:
			return("arcs");
		default:
			if(type == adImageEnttype(dwg->handle)) 
				return("images");
			if(type == adLwplineEnttype(dwg->handle))
				return("plines");
			return("");
		}
	}
	
/*-------------------------DESTRUCTOR---------------------------------*/
void DESTROY(SV* obj) {
	DWGstruct* dwg = (DWGstruct*) SvIV(SvRV(obj));
	if(dwg->file_is_open) {
		//printf("closing file\n");
		adCloseFile(dwg->handle);
		}
	//printf("freeing memory\n");
	//free(dwg->current_layer);
	free(dwg->adxd);
	free(dwg->adtb);
	free(dwg->aden);
	free(dwg->adenhd);
	adCloseAd2();
	free(dwg);
	}
/*--------------------------------------------------------------------*/
// this function was adapted from the OpenDWG toolkit example
// it allocates memory for the pointers stored in the main struct
int allocateadptrs(DWGstruct* dwg) {
	//printf("allocating memory\n");
	if ((dwg->adenhd=(PAD_ENT_HDR)malloc(sizeof(AD_ENT_HDR)))!=NULL) {
		if ((dwg->aden=(PAD_ENT)malloc(sizeof(AD_ENT)))!=NULL) {
			if ((dwg->adtb=(PAD_TB)malloc(sizeof(AD_TB)))!=NULL) {
				if ((dwg->adxd=(PAD_XD)malloc(sizeof(AD_XD)))!=NULL) {
					return(1);
					}
				free(dwg->adtb);
				}
			free(dwg->aden);
			}
		free(dwg->adenhd);
		}
	return(0);
	}
