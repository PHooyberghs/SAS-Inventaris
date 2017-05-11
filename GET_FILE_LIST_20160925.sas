%macro GET_FILE_LIST_20160925
		(
		T_PATH=,					/* Windows PATH of directory to examine											*/
		T_USER_ID=,				/* [optional] windows domain and user initials	i.e. nuwem\hsp				*/
		T_DATE_MIN=,			/* [optional] minimum date/time of file to report								*/
		T_DATE_MAX=,			/* [optional] maximum date/time of file to report								*/
		N_BYTES_SIZE_MIN=,	/* [optional] minimum SIZE of file to report (bytes)							*/
		N_BYTES_SIZE_MAX=,	/* [optional] maximum SIZE of file to report (bytes)							*/
		T_DS_OUT_PATH=,			/* [optional] PATH for output filelist dataset (default PATH work 		*/
		T_DS_OUT_NAME=,		/* [optional] name of output file containing results of %DIRLISTWIN		*/
		L_SUBDIR=Y,				/* [optional] include subdirectories in directory processing				*/
		T_FILE_FILTER=*.* 	/* [optional] all folders but only files matching the filter are listed	*/
		)
		;
	options noquotelenmax;
	/*options nonotes nomprint nomlogic nosymbolgen nosource;*/
	options noxwait xsync;

	/* check PATH and logical value subdirectorys */
		/* PATH */
		%if %sysevalf(%superq(T_PATH)=,boolean)^=0 %then %do;
				%put ERROR: NO PATH DEFINED;
				%abort cancel;
			%end;
		%else %if %eval(%sysfunc(fileexist(&T_PATH.))=0) %then %do;
				%put ERROR: PATH "&T_PATH.";
				%put ERROR: PATHs does not exist or is not accessible;
				%abort cancel;
			%end;
		%let T_PATH=%sysfunc(dequote(&T_PATH.));

		/* subdirectorys? */
		%let L_SUBDIR_LOC=0;
		%if %sysevalf(%superq(L_SUBDIR)=,boolean)=0 %then %do;
				%if %sysfunc(dequote(&L_SUBDIR.))=Y %then %do;
						%let L_SUBDIR_LOC=1;
					%end;
			%end;
		%else %do;
				%let L_SUBDIR_LOC=1;
			%end;

	/* lib and ds_out */
%put T_DS_OUT_PATH: &T_DS_OUT_PATH.;
	%if %sysevalf(%superq(T_DS_OUT_PATH)=,boolean)=0 %then %do;
			%let T_DS_OUT_PATH=%sysfunc(dequote(&T_DS_OUT_PATH.));
			%if %eval(%sysfunc(fileexist(&T_DS_OUT_PATH.))>0) %then %do;
					libname lib_out "&T_DS_OUT_PATH.";
					%let LIB_OUT=LIB_OUT;
				%end;
			%else %do;
					%put ERROR: Output PATH does not exist or is not accessible;
					%abort cancel;
				%end;
		%end;
	%else %let LIB_OUT=WORK;

	%if %sysevalf(%superq(T_DS_OUT_NAME)=,boolean)=0 %then %do;
			%let T_OUT_DS=%sysfunc(dequote(&T_DS_OUT_NAME.));
		%end;
	%else %let T_OUT_DS=SAS_FILELIST;
/*%put T_OUT_DS: &T_OUT_DS.;*/

	/* user_id */
	%let T_USER_FILTER=;
	%if %sysevalf(%superq(T_USER_ID)=,boolean)=0 %then %do;
			%let T_USER_ID_LOC=%sysfunc(dequote(&T_USER_ID.));
			%let T_USER_FILTER=and T_OWNER="T_USER_ID_LOC";
		%end;

	/* minimum date */
	%let T_DATE_MIN_FILTER=;
	%if %sysevalf(%superq(T_DATE_MIN)=,boolean)=0 %then %do;
			%let T_DATE_MIN_FILTER=%sysfunc(dequote(&T_DATE_MIN.));
			%let T_DATE_MIN_FILTER=and D_LAST_CHANGED>="&T_DATE_MIN_FILTER."d;
		%end;

	/* maximum date */
	%let T_DATE_MAX_FILTER=;
	%if %sysevalf(%superq(T_DATE_MAX)=,boolean)=0 %then %do;
			%let T_DATE_MAX_FILTER=%sysfunc(dequote(&T_DATE_MAX.));
			%let T_DATE_MAX_FILTER=and D_LAST_CHANGED<="&T_DATE_MAX_FILTER."d;
		%end;

	/* minimum SIZE */
	%let T_SIZE_MIN_FILTER=;
	%if %sysevalf(%superq(N_BYTES_SIZE_MIN)=,boolean)=0 %then %do;
			%let T_SIZE_MIN_FILTER=%sysfunc(dequote(&N_BYTES_SIZE_MIN.));
			%let T_SIZE_MIN_FILTER=and N_SIZE_BYTES>=&T_SIZE_MIN_FILTER.;
		%end;

	/* minimum SIZE */
	%let T_SIZE_MAX_FILTER=;
	%if %sysevalf(%superq(N_BYTES_SIZE_MAX)=,boolean)=0 %then %do;
			%let T_SIZE_MAX_FILTER=%sysfunc(dequote(&N_BYTES_SIZE_MAX.));
			%let T_SIZE_MAX_FILTER=and N_SIZE_BYTES<=&T_SIZE_MAX_FILTER.;
		%end;

	/* prepare file filter by translating them into regular expressions */
	%let L_FILE_FILTER=0;
	%let N_FILE_FILTER_IDX=0;
	%if %sysevalf(%superq(T_FILE_FILTER)=,boolean)=0 %then %do;
			%let L_FILE_FILTER=1;
			%let T_FILE_FILTER_LOC=;
			%let N_FILE_FILTER_IDX=1;
			%let FILTER_TMP=%scan(&T_FILE_FILTER.,&N_FILE_FILTER_IDX.,' ');
			%do %while("&FILTER_TMP."^="");
					%let FILTER_TMP=%sysfunc(strip(&FILTER_TMP.));
					%let FILTER_TMP=%sysfunc(prxchange(s/\./\.{1}/,-1,&FILTER_TMP.));
					%let FILTER_TMP=%sysfunc(prxchange(s/\*/.*/,-1,&FILTER_TMP.));
					%let FILTER_TMP=%sysfunc(prxchange(s/\?/.{1}/,-1,&FILTER_TMP.));
					%let T_FILE_FILTER_&N_FILE_FILTER_IDX.=/%sysfunc(strip(&FILTER_TMP.))$/;
					%let N_FILE_FILTER_IDX=%eval(&N_FILE_FILTER_IDX.+1);
					%let FILTER_TMP=%scan(&T_FILE_FILTER.,&N_FILE_FILTER_IDX.,' ');
				%end;
			%let N_FILE_FILTER_IDX=%eval(&N_FILE_FILTER_IDX.-1);
			/*%put N_FILE_FILTER_IDX: &N_FILE_FILTER_IDX.;
			%do i=1 %to &N_FILE_FILTER_IDX.;
					%Put filter &i.: &&T_FILE_FILTER_&i.;
				%end;*/
		%end;

	/* 1. get filelist */

	
   /*============================================================================*/
   /* external storage references
   /*============================================================================*/
   /* run Windows "dir" DOS command as pipe to get contents of data directory */

	%if L_SUBDIR_LOC=0 %then %do;
		   FILENAME DIRLIST pipe "dir /-c /q  /t:c ""&T_PATH""" ;
		%end;
	%else %do;
			FILENAME DIRLIST pipe "dir /-c /q /s /t:c ""&T_PATH""" ;
		%end;
   %let DELIM   = ' ' ;


   /*############################################################################*/
   /* begin executable code
   /*############################################################################*/
   data &LIB_OUT..&T_OUT_DS. /*(drop=EXTENSION_TMP)*/;
      length PATH $512;
		format PATH $512.;
		length FILENAME $255;
		format FILENAME $255.;
		length FILENAME_TMP $255;
		format FILENAME_TMP $255.;
		length EXTENSION $30;
		format EXTENSION $30.;
		/*length EXTENSION_TMP $30;
		format EXTENSION_TMP $30.;*/
		length T_OWNER $17;
		format T_OWNER $17.;
		length N_SIZE_BYTES 8;
		format N_SIZE_BYTES 10.;
		length D_LAST_CHANGED 8;
		format D_LAST_CHANGED date9.;
		format T_LAST_CHANGED HHMM5.;
		length N_SUBDIR 3;
		format N_SUBDIR 3.;
		length L_FILE 3;
		format L_FILE 3.;
		length line $1024;
		format line $1024.;
		length TEMP $16 ;
		format TEMP $16.;

		retain PATH ;

      infile DIRLIST length=reclen ;
      input line $varying1024. reclen ;


		if _N_=1 then do;
			%if %eval(&N_FILE_FILTER_IDX.>0) %then %do;
					%do i=1 %to &N_FILE_FILTER_IDX.;
							retain oRE_&i.;
							oRE_&i.=prxparse("&&T_FILE_FILTER_&i.");
							/*%put "&&T_FILE_FILTER_&i." parsed to oRE_&i.;*/
						%end;
				%end;
			end;
	 
		if mod(_N_,100)=0 then rc=dosubl(cat('SYSECHO "processing ',_N_,' files";'));

      if reclen = 0 then delete ;

      if scan( line, 1, &DELIM ) = 'Volume'  | /* beginning of listing */
         scan( line, 1, &DELIM ) = 'Total'   | /* antepenultimate line */
         scan( line, 2, &DELIM ) = 'File(s)' | /* penultimate line     */
         scan( line, 2, &DELIM ) = 'Dir(s)'    /* ultimate    line     */
      then delete ;

      dir_rec = upcase( scan( line, 1, &DELIM )) = 'DIRECTORY' ;
		L_FILE=1;
		if prxmatch("/<DIR>/",upcase(line))>0 or dir_rec then L_FILE=0;

      /* parse directory     record for directory PATH
       * parse non-directory record for FILENAME, associated information
       */

      if dir_rec then PATH = left( substr( line, length( "Directory of" ) + 2 )) ;
      else do ;
	         D_LAST_CHANGED = input( scan( line, 1, &DELIM. ), ddmmyy10. ) ;
	         T_LAST_CHANGED = input( scan( line, 2, &DELIM. ), time5. ) ;
	         TEMP = scan( line, 3, &DELIM. );
	         if TEMP = '<DIR>' then N_SIZE_BYTES = 0 ; else N_SIZE_BYTES = input( TEMP, best. );
	         T_OWNER = scan( line, 4, &DELIM. );

         /* scan delimiters cause FILENAME parsing to require special treatment */

         FILENAME_TMP = scan( line, 5, &DELIM. ) ;

         if FILENAME_TMP in ( '.' '..' ) then delete ;

         ndx = index( line, scan( FILENAME_TMP, 1 )) ;

         FILENAME_TMP = substr( line, ndx ) ;
			
      end ;
		N_SUBDIR=count(PATH,"\");
		if L_FILE>0 then do;
				EXTENSION="";
				do while (prxmatch("/^.+\.{1}[A-Za-z]+$/",strip(FILENAME_TMP))>0);
						EXTENSION=cats(prxchange("s/^(.+)(\.{1}[A-Za-z\d]+)$/$2/",-1,strip(FILENAME_TMP)),EXTENSION);
						FILENAME_TMP=prxchange("s/^(.+)(\.{1}[A-Za-z\d]+)$/$1/",-1,strip(FILENAME_TMP));
					end;
				EXTENSION=lowcase(EXTENSION);
				FILENAME=FILENAME_TMP;
			end;
		drop 
				dir_rec
				line
				ndx
				TEMP
				FILENAME_TMP
				%do i=1 %to &N_FILE_FILTER_IDX.;
						oRE_&i.
					%end;
				;

		if 
			1=1
			&T_USER_FILTER.
			&T_DATE_MIN_FILTER.
			&T_DATE_MAX_FILTER.
			&T_SIZE_MIN_FILTER.
			&T_SIZE_MAX_FILTER.
			%if %eval(&N_FILE_FILTER_IDX.>0) %then %do;
					and
					(
					1^=1
					%do i=1 %to &N_FILE_FILTER_IDX.;
							or
							prxmatch(oRE_&i.,strip(lowcase(EXTENSION)))>0
						%end;
					)
				%end;
			;
   run;quit;

%leave:
FILENAME DIRLIST clear;
%mend;

/*%GET_FILE_LIST_20160925
				(
				T_PATH=\\Srsasd1\sasdata\Users\HSP,
				T_USER_ID=,		
				T_DATE_MIN=,
				T_DATE_MAX=,
				N_BYTES_SIZE_MIN=,
				N_BYTES_SIZE_MAX=,
				T_DS_OUT_PATH=,
				T_DS_OUT_NAME=,
				L_SUBDIR=Y,
				T_FILE_FILTER=.sas .zip .xml .sas*dat .egp
				)
				;*/

/*.sas?bdat .xml .sas*/

/*
%include "\\srsasd1\sasdata\Users\HSP\MyMacros\SAS_INVENTARIS\GET_FILE_LIST_20160925.sas";
%let UNZIP_PATH=\\nuvem.intra\FPS-SocSec\Users\HSP\SAS_CODE_INVENTARIS\Test_20170414\EXTRACTIONS\CADASTER_ABT_FOREIGNEMPLOYER_20150911_uz\UNZIPPED;
%let FLELIST_PATH=\\nuvem.intra\FPS-SocSec\Users\HSP\SAS_CODE_INVENTARIS\Test_20170414\EXTRACTIONS\CADASTER_ABT_FOREIGNEMPLOYER_20150911_uz\FILELIST;
%GET_FILE_LIST_20160925
			(
			T_PATH=&UNZIP_PATH.,
			T_DS_OUT_PATH=&FLELIST_PATH.,
			T_DS_OUT_NAME=FILELIST_SCI,
			L_SUBDIR=Y,
			T_FILE_FILTER=*.sas
			)
			;
*/
/*
%include "\\srsasd1\sasdata\Users\HSP\MyMacros\SAS_INVENTARIS\GET_FILE_LIST_20160925.sas";
%let UNZIP_PATH=\\nuvem.intra\FPS-SocSec\Users\HSP\SAS_CODE_INVENTARIS\Test_20170414\EXTRACTIONS\CTRL_OA_COUNTRY_20141016_BU_uz\UNZIPPED;
%let FLELIST_PATH=\\nuvem.intra\FPS-SocSec\Users\HSP\SAS_CODE_INVENTARIS\Test_20170414\EXTRACTIONS\CTRL_OA_COUNTRY_20141016_BU_uz\FILELIST;
%GET_FILE_LIST_20160925
			(
			T_PATH=&UNZIP_PATH.,
			T_DS_OUT_PATH=&FLELIST_PATH.,
			T_DS_OUT_NAME=FILELIST_SCI,
			L_SUBDIR=Y,
			T_FILE_FILTER=*.sas
			)
			;
*/