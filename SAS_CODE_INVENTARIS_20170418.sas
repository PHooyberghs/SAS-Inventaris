/* sas project and code inventaris */

/*
base structure  macro

	1. file extension .zip, .7z
		Starting with compressed file archives because they can contain all kind of files, including eg-projects and macro-files.
		All archives will be unzipped to their proper subfolder in one main ARCH_UNZIPPED -folder
		- list files .zip and .7z from base path (other compressed file archives, not egp?)
		- unzipp archives to ARCH_UNZIPPED -folder

	2. file extension .egp
		EG-projects are in fact also compressed file archives, containing in its root one file 'project.xml'.
		It contains also a unique folder for each object embedded in the project (embedded datasets, point&click elements
		like query s, and all embedded programs.
		To retrieve embedded code, it suffices to loop  trough al subfolders and keep all files with extension .sas.
		However, this will not retrieve more detailled information (like input and output dataset names, query definition
		for point&click querys), the project.xml file needs to be parsed and treated by more avanced code.
		All EG-projects will be unzipped to their proper subfolder in one main EGP_UNZIPPED-folder
		- list EG-projects from base path AND from ARCH_UNZIPPED
		- unzipp EG-projects to EGP_UNZIPPED -folder

	3. find all sas code files (filesystem files as well as project embedded code files) and collect
		them all in SAS_CODE_COLLECTION

	4. find all definitions user defined functions (!!! function dataset properties) and 
		find all macro definitions (independent macros as well as macro embedded macros, make distinction) and
		list them including meta-information.

	5. find dependencies (first level), then continue looking for indirect dependencies (not only dependencies for 
		one macro to another, but also depenendies of base programs (not macro)
*/

%macro test(NAME=);
	%put Name=&name.;
%mend;

%macro Compressed_objects
		(
		T_PATH_MACROS=,
		T_PATH_SOURCE=,
		T_PATH_TARGET=
		)
		/parmbuff minoperator
		;

	options noxwait xsync notes source;

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:		Macro started;
	%put NOTE: ******************************************************;
	%put ;

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE: 		Start initializing variables, make base folders;
	%put NOTE: ******************************************************;
	%put ;

	%local T_PATH_MACROS_COBJ;
	%local T_PATH_SOURCE_COBJ;
	%local T_PATH_TARGET_COBJ;
	%local T_DS_OUT_PATH_LIST_COBJ;
	%local T_DS_OUT_NAME_LIST_COBJ;
	%local T_PATH_EXTRACT_COBJ;
	%local T_PATH_LOG_COBJ;

	%let T_PATH_MACROS_COBJ=%sysfunc(dequote(&T_PATH_MACROS.));
	%let T_PATH_SOURCE_COBJ=%sysfunc(dequote(&T_PATH_SOURCE));
	%let T_PATH_TARGET_COBJ=%sysfunc(dequote(&T_PATH_TARGET.));
	%let T_DS_OUT_PATH_LIST_COBJ=&T_PATH_TARGET_COBJ.\TMP;
	%let T_DS_OUT_NAME_LIST_COBJ=LST_COMPR_OBJ;
	%let T_PATH_EXTRACT_COBJ=&T_PATH_TARGET_COBJ.\EXTRACTIONS;
	%let T_PATH_LOG_COBJ=&T_PATH_TARGET_COBJ.\LOG;


	%sysexec rmdir /s /q "&T_DS_OUT_PATH_LIST_COBJ.";
	%sysexec rmdir /s /q "&T_PATH_EXTRACT_COBJ.";
	%sysexec rmdir /s /q "&T_PATH_LOG_COBJ.";
	/*%let rc=sysfunc(sleep(30));*/

	%sysexec mkdir "&T_DS_OUT_PATH_LIST_COBJ.";
	%sysexec mkdir "&T_PATH_EXTRACT_COBJ.";
	%sysexec mkdir "&T_PATH_LOG_COBJ.";
	/*%let rc=sysfunc(sleep(30));*/

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE: 		Finished initializing variables, make base folders;
	%put NOTE: ******************************************************;
	%put ;

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:			Start getting list compressed objects;
	%put NOTE: ******************************************************;
	%put ;

	%include "&T_PATH_MACROS_COBJ.\SAS_INVENTARIS\GET_FILE_LIST_20160925.sas";
	proc printto;
	run;quit;
	/*
	%GET_FILE_LIST_20160925
				(
				T_PATH=&T_PATH_COB.,
				T_DS_OUT_PATH=&T_DS_OUT_PATH_LIST_COB.,
				T_DS_OUT_NAME=&T_DS_OUT_NAME_LIST_COB.,
				L_SUBDIR=Y,
				T_FILE_FILTER=.zip .egp
				)
				;
	*/

	%GET_FILE_LIST_20160925
				(
				T_PATH=&T_PATH_SOURCE_COBJ.,
				T_DS_OUT_PATH=&T_DS_OUT_PATH_LIST_COBJ.,
				T_DS_OUT_NAME=&T_DS_OUT_NAME_LIST_COBJ.,
				L_SUBDIR=Y,
				T_FILE_FILTER=.egp
				)
				;
	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:			Finished getting list compressed objects;
	%put NOTE: ******************************************************;
	%put ;

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:			Start preparing variables remote processes;
	%put NOTE: ******************************************************;
	%put ;

	proc sort data="&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat";
		by FILENAME;
	run;quit;

	data "&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat";
		set "&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat" end=eof;

		length T_EGP_NAME_PREV $124;
		format T_EGP_NAME_PREV $124.;
		retain T_EGP_NAME_PREV;

		length T_MAP_EXTRACT_FINAL $124;
		format T_MAP_EXTRACT_FINAL $124.;

		length O_MAP_EXTRACT_FINAL 8;
		format O_MAP_EXTRACT_FINAL 8.;
		retain O_MAP_EXTRACT_FINAL;

		length L_O_MAP_EXTRACT_MODIFIED 3;
		format L_O_MAP_EXTRACT_MODIFIED 1.;
	
		if _N_=1 then do;
				T_EGP_NAME_PREV="";
				O_MAP_EXTRACT_FINAL=0;
			end;
		if N_SIZE_BYTES>0 then do;
				L_O_MAP_EXTRACT_MODIFIED=0;
				T_MAP_EXTRACT_FINAL=prxchange("s/[^\w\d]/_/",-1,strip(FILENAME));
				if strip(T_MAP_EXTRACT_FINAL)^=strip(FILENAME) then do;
						L_O_MAP_EXTRACT_MODIFIED=1;
					end;

				if FILENAME=T_EGP_NAME_PREV then do;
						O_MAP_EXTRACT_FINAL=O_MAP_EXTRACT_FINAL+1;
						T_MAP_EXTRACT_FINAL=catx("_",T_MAP_EXTRACT_FINAL,cats("extr_",put(O_MAP_EXTRACT_FINAL,z5.)));
					end;
				else do;
						T_EGP_NAME_PREV=FILENAME;
						O_MAP_EXTRACT_FINAL=0;
						T_MAP_EXTRACT_FINAL=catx("_",T_MAP_EXTRACT_FINAL,"uz");
					end;
			end;
		else do;
				T_MAP_EXTRACT_FINAL="EGP ERR";
			end;
	run;

	proc sort data="&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat";;
		by descending N_SIZE_BYTES;
	run;quit;

	data "&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat";
		set "&T_DS_OUT_PATH_LIST_COBJ.\&T_DS_OUT_NAME_LIST_COBJ..sas7bdat" end=eof;

		length N_EGP_SRCE 8;
		format N_EGP_SRCE 8.;
		retain N_EGP_SRCE;

		if _N_=1 then do;
				N_EGP_SRCE=0;
			end;
		if T_MAP_EXTRACT_FINAL^="EGP ERR" then do;
				N_EGP_SRCE=N_EGP_SRCE+1;
				call symput("T_PATH_EGP_SRCE_"||strip(N_EGP_SRCE),PATH);
				call symput("T_NAME_EGP_SRCE_"||strip(N_EGP_SRCE),FILENAME);
				call symput("T_MAP_EXTRACT_FINAL_"||strip(N_EGP_SRCE),T_MAP_EXTRACT_FINAL);
				call symput("L_O_MAP_EXTRACT_MOD_"||strip(N_EGP_SRCE),L_O_MAP_EXTRACT_MODIFIED);
			end;
		if eof then call symput("N_EGP_SRCE",N_EGP_SRCE);
	run;

	%do obj_idx=1 %to &N_EGP_SRCE.;
	/*%do obj_idx=1 %to 25;*/
			%put obj_idx: &obj_idx.;
			%put T_PATH_EGP_SRCE_&obj_idx.: &&T_PATH_EGP_SRCE_&obj_idx..;
			%put T_NAME_EGP_SRCE_&obj_idx.: &&T_NAME_EGP_SRCE_&obj_idx..;
			%put T_MAP_EXTRACT_FINAL_&obj_idx. : &&T_MAP_EXTRACT_FINAL_&obj_idx..;
			%put L_O_MAP_EXTRACT_MOD_&obj_idx. : &&L_O_MAP_EXTRACT_MOD_&obj_idx..;
			%put ;
		%end;

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:			Finished preparing variables remote processes;
	%put NOTE:			N_EGP_SRCE: &N_EGP_SRCE.;
	%put NOTE: ******************************************************;
	%put ;

	/* prepare remote processes */
	%goto REMOTE_PREPARE;
	%REMOTE_PREPARE_DONE:

	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:			loop trough EG Projects (Zip files?);
	%put NOTE:			!!! Remote processes used;
	%put NOTE: ******************************************************;
	%put ;

	/* loop trough eg projects to extract all embedded sas code */
	%do obj_idx=1 %to &N_EGP_SRCE.;
	/*%do obj_idx=1 %to 25;*/
			/* look for free remote process */
			%goto FREE_PROCESS;
			%FREE_PROCESS_DONE:

			%if %eval(&L_FREE_FOUND.=0) %then %goto m_leave;

			%let T_PROCESS_FREE=RPROC_&O_PROCESS_FREE.;
			%let L_DONE_&O_PROCESS_FREE.=0;
			%let T_PATH_EXTRACT_FINAL=&T_PATH_EXTRACT_COBJ.\&&T_MAP_EXTRACT_FINAL_&obj_idx..;
			%sysexec mkdir "&T_PATH_EXTRACT_FINAL.";
			
			%put obj_idx: &obj_idx.;
			%put T_PROCESS_FREE: &T_PROCESS_FREE.;
			%put T_PATH_EXTRACT_FINAL: &T_PATH_EXTRACT_FINAL.;
			%put T_PATH_EGP_SRCE_&obj_idx.: &&T_PATH_EGP_SRCE_&obj_idx..;
			%put T_NAME_EGP_SRCE_&obj_idx.: &&T_NAME_EGP_SRCE_&obj_idx..;
			%put T_MAP_EXTRACT_FINAL_&obj_idx. : &&T_MAP_EXTRACT_FINAL_&obj_idx..;
			%put L_O_MAP_EXTRACT_MOD_&obj_idx. : &&L_O_MAP_EXTRACT_MOD_&obj_idx..;

			%syslput T_PROCESS_FREE=&T_PROCESS_FREE./remote=&T_PROCESS_FREE.;
			%syslput O_PROCESS_FREE=&O_PROCESS_FREE./remote=&T_PROCESS_FREE.;
			%syslput T_PATH_MACROS=&T_PATH_MACROS./remote=&T_PROCESS_FREE.;
			%syslput T_PATH_EGP_SRCE=&&T_PATH_EGP_SRCE_&obj_idx../remote=&T_PROCESS_FREE.;
			%syslput T_NAME_EGP_SRCE=&&T_NAME_EGP_SRCE_&obj_idx../remote=&T_PROCESS_FREE.;
			%syslput T_PATH_EXTRACT_FINAL=&T_PATH_EXTRACT_FINAL./remote=&T_PROCESS_FREE.;
			%syslput L_O_MAP_EXTRACT_MODIFIED=&&L_O_MAP_EXTRACT_MOD_&obj_idx../remote=&T_PROCESS_FREE.;
			/*%syslput T_PATH_EXTRACTIONS=&T_PATH_EXTRACT_COBJ./remote=&T_PROCESS_FREE.;*/

			rsubmit &T_PROCESS_FREE. wait=no sysrputsync=yes;
					%nrstr(%global LRP_DONE_&O_PROCESS_FREE.;)
					%nrstr(%let LRP_DONE_&O_PROCESS_FREE.=98;)
					%nrstr(%global T_ETXT_&O_PROCESS_FREE.;)
					%nrstr(%let T_ETXT_&O_PROCESS_FREE.=;)

					%macro EMBEDDED_CODE_EXTRACT;

							filename LOG_RP "&T_PATH_EXTRACT_FINAL.\LOG_EXTRACT.log";
							proc printto log=LOG_RP new;
							run;quit;
							%put NOTE: **************************************************;
							%put NOTE: OBJ_EGP: &T_PATH_EGP_SRCE.\&T_NAME_EGP_SRCE..egp;
							%put NOTE:	**************************************************;
							%if %eval(&L_O_MAP_EXTRACT_MODIFIED.>0) %then %do;
									%put NOTE: name EG Project modified before useing as name extractions folder;
									%put NOTE:	**************************************************;
								%end;


							%put T_PROCESS_FREE: &T_PROCESS_FREE.;
							%put O_PROCESS_FREE: &O_PROCESS_FREE.;
							%put T_PATH_MACROS: &T_PATH_MACROS.;
							%put T_PATH_EGP_SRCE: &T_PATH_EGP_SRCE.;
							%put T_NAME_EGP_SRCE: &T_NAME_EGP_SRCE.;
							%put T_PATH_EXTRACT_FINAL: &T_PATH_EXTRACT_FINAL.;
							%put L_O_MAP_EXTRACT_MODIFIED: & L_O_MAP_EXTRACT_MODIFIED.;
							%put;
							/*%put T_PATH_EXTRACTIONS: &T_PATH_EXTRACTIONS.;*/
	
							options noxwait xsync;
							options notes source source2;

							%include "&T_PATH_MACROS.\MACROS_GENERAL\SASZip_Lite.sas";
							%include "&T_PATH_MACROS.\SAS_INVENTARIS\GET_FILE_LIST_20160925.sas";
							%include "&T_PATH_MACROS.\SAS_INVENTARIS\PARSE_EG_PROJECT_XML.sas";
							%if %eval(&syserr.>0) %then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=&syserr.;
									%let T_ETXT_&O_PROCESS_FREE.=&syserrortext.;
									%put LRP_DONE_&O_PROCESS_FREE.: &&LRP_DONE_&O_PROCESS_FREE..;
									%put T_ETXT_&O_PROCESS_FREE.: &&T_ETXT_&O_PROCESS_FREE..;
									%goto m_leave;
								%end;

							%let T_PATH_UNZIPPED=&T_PATH_EXTRACT_FINAL.\UNZIPPED;
							%let T_PATH_EGP_PARSED=&T_PATH_EXTRACT_FINAL.\EGP_PARSED;
							%let T_PATH_EGP_FILELIST=&T_PATH_EXTRACT_FINAL.\FILELIST;
							%let T_PATH_EGP_ZIP=&T_PATH_EXTRACT_FINAL.\EGP_ZIP;

							%sysexec mkdir "&T_PATH_UNZIPPED.";
							%sysexec mkdir "&T_PATH_EGP_PARSED.";
							%sysexec mkdir "&T_PATH_EGP_FILELIST.";
							%sysexec mkdir "&T_PATH_EGP_ZIP.";
							%put NOTE: ***************************;
							%put NOTE: Temporary folders created;
							%put NOTE: ***************************;
							%put;

							%let OBJ_EGP=&T_PATH_EGP_SRCE.\&T_NAME_EGP_SRCE..egp;
							%let OBJ_EGP_ZIP=&T_PATH_EGP_ZIP.\&T_NAME_EGP_SRCE..zip;
							%sysexec copy "&OBJ_EGP." "&OBJ_EGP_ZIP.";

							%if %eval(&syserr.>0) %then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=&syserr.;
									%let T_ETXT_&O_PROCESS_FREE.=&syserrortext.;
									%put LRP_DONE_&O_PROCESS_FREE.: &&LRP_DONE_&O_PROCESS_FREE..;
									%put T_ETXT_&O_PROCESS_FREE.: &&T_ETXT_&O_PROCESS_FREE..;
									%goto m_leave;
								%end;

							%if %sysfunc(fileexist(&OBJ_EGP_ZIP.))^=1 %then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=10;
									%let T_ETXT_&O_PROCESS_FREE.=Creation zip file from eg project failed;
									%put LRP_DONE_&O_PROCESS_FREE.: &&LRP_DONE_&O_PROCESS_FREE..;
									%put T_ETXT_&O_PROCESS_FREE.: &&T_ETXT_&O_PROCESS_FREE..;
									%goto m_leave;
								%end;

							%put NOTE: ***************************;
							%put NOTE: zip copy created;
							%put NOTE: ***************************;
							%put;

							%global T_UZ_PATH_RETURN;
							%put OBJ_EGP_ZIP: &OBJ_EGP_ZIP.;
							%put T_PATH_UNZIPPED: &T_PATH_UNZIPPED.;
							%put T_UZ_PATH_RETURN: &T_UZ_PATH_RETURN.;

							%let T_UZ_ATTEMPT=0;
							%let L_UZ_OK=0;
							%do %while(%eval(&L_UZ_OK.=0) and %eval(&T_UZ_ATTEMPT.<5));
									%let T_UZ_ATTEMPT=%eval(&T_UZ_ATTEMPT.+1);
									%let L_UZ_OK=1;
									%SASZip_Lite(
											zip=&OBJ_EGP_ZIP.,
											sfdr=,
											tfdr=&T_PATH_UNZIPPED.,
											overwrite=Y,
											create_extra=N,
											T_VAR_DESTINATION_RET=T_UZ_PATH_RETURN
											)
											;
									proc printto log=LOG_RP;
									run;quit;
									%if %sysfunc(fileexist(&T_PATH_UNZIPPED.\project.xml))^=1 %then %do;
											%let L_UZ_OK=0;
											%let rc=%sysfunc(sleep(15));
										%end;
									%put T_UZ_PATH_RETURN: &T_UZ_PATH_RETURN.;
								%end;
							%if %sysfunc(fileexist(&T_PATH_UNZIPPED.\project.xml))^=1 %then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=11;
									%let T_ETXT_&O_PROCESS_FREE.=Project unzip failed;
									%goto m_leave;
								%end;
							%put NOTE: ***************************;
							%put NOTE: unzip succeeded;
							%put NOTE: ***************************;
							%put;

							%sysexec del "&OBJ_EGP_ZIP.";
					
							/*%put T_PATH_EGP_PARSED: &T_PATH_EGP_PARSED.;
							%put T_EG_PROJECT_FULL_PATH: &T_PATH_UNZIPPED.\project.xml;
							%global L_EXTRACT_NOK;
							%global L_PARSE_EG_PROJECT_OK;
									%PARSE_EG_PROJECT_XML
										(
										T_EG_PROJECT_FULL_PATH=&T_PATH_UNZIPPED.\project.xml,
										T_MAP_OUT_FULL_PATH="&T_PATH_EGP_PARSED.",
										T_VAR_RETURN=L_PARSE_EG_PROJECT_OK
										)
										;
							%put L_PARSE_EG_PROJECT_OK: &L_PARSE_EG_PROJECT_OK.;*/

							%global L_EXTRACT_NOK;
							%let L_EXTRACT_NOK=99;
							%let N_EXTRACT_ATTEMPT=0;
							%let L_PARSE_OK=0;
							%do %while(%eval(&L_PARSE_OK.=0) and %eval(&N_EXTRACT_ATTEMPT.<5));
									%let N_EXTRACT_ATTEMPT=%eval(&N_EXTRACT_ATTEMPT.+1);
									%let L_PARSE_OK=1;							
									%PARSE_EG_PROJECT_XML
										(
										T_EG_PROJECT_FULL_PATH=&T_PATH_UNZIPPED.\project.xml,
										T_MAP_OUT_FULL_PATH=&T_PATH_EGP_PARSED.,
										T_VAR_RETURN=L_EXTRACT_NOK,
										LOG=LOG_RP
										)
										;
									proc printto log=LOG_RP;
									run;quit;
									%put Parsing attempt: &N_EXTRACT_ATTEMPT.;
									%put L_EXTRACT_NOK: &L_EXTRACT_NOK.;
									%put;
									%if 
											%eval(&L_EXTRACT_NOK.>0)
											or
											%sysfunc(fileexist(&T_PATH_EGP_PARSED.\embedded_code_map.sas7bdat))^=1
											or
											%sysfunc(fileexist(&T_PATH_EGP_PARSED.\parent_details_code_parent.sas7bdat))^=1
											or
											%sysfunc(fileexist(&T_PATH_EGP_PARSED.\xml_parsed.sas7bdat))^=1
											%then %do;
											%let L_PARSE_OK=0;
											%let rc=%sysfunc(sleep(15));
										%end;
								%end;
							%if 
									%eval(&L_EXTRACT_NOK.>0)
									or
									%sysfunc(fileexist(&T_PATH_EGP_PARSED.\embedded_code_map.sas7bdat))^=1
									or
									%sysfunc(fileexist(&T_PATH_EGP_PARSED.\parent_details_code_parent.sas7bdat))^=1
									or
									%sysfunc(fileexist(&T_PATH_EGP_PARSED.\xml_parsed.sas7bdat))^=1
									%then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=12;
									%let T_ETXT_&O_PROCESS_FREE.=Project parsing failed;
									%goto m_leave;
								%end;

							%put NOTE: ***************************;
							%put NOTE: parsing succeeded;
							%put NOTE: ***************************;
							%put;


							%let L_FILELIST_OK=0;
							%let N_FILELIST_ATTEMPT=0;
							%do %while(%eval(&L_FILELIST_OK.=0) and %eval(&N_FILELIST_ATTEMPT.<5));
									%let L_FILELIST_OK=1;
									%let N_FILELIST_ATTEMPT=%eval(&N_FILELIST_ATTEMPT.+1);
									%GET_FILE_LIST_20160925
												(
												T_PATH=&T_PATH_UNZIPPED.,
												T_DS_OUT_PATH=&T_PATH_EGP_FILELIST.,
												T_DS_OUT_NAME=FILELIST_SCI,
												L_SUBDIR=Y,
												T_FILE_FILTER=.sas
												)
												;
									proc printto log=LOG_RP;
									run;quit;
									%put;
									%if %sysfunc(fileexist(&T_PATH_EGP_FILELIST.\FILELIST_SCI.sas7bdat))^=1 or
											%sysfunc(fileexist(&T_PATH_EGP_FILELIST.\FILELIST_SCI.sas7bdat.lck))=1
											%then %do;
											%let L_FILELIST_OK=0;
											%put Filelist attempt: &N_FILELIST_ATTEMPT.;
											%put L_FILELIST_OK: &L_FILELIST_OK.;
											%let rc=%sysfunc(sleep(15));
										%end;
								%end;
							%if %sysfunc(fileexist(&T_PATH_EGP_FILELIST.\FILELIST_SCI.sas7bdat))^=1 %then %do;
									%let LRP_DONE_&O_PROCESS_FREE.=13;
									%let T_ETXT_&O_PROCESS_FREE.=Getting filelist unzipped files failed;
									%goto m_leave;
								%end;
							%put NOTE: ***************************;
							%put NOTE: FILELIST build;
							%put NOTE: ***************************;
							%put;

							proc sql;
								create table "&T_PATH_EGP_PARSED.\EMBEDDED_CODE.sas7bdat" as
									select distinct
										pdcp.L_EMBEDDED,
										pdcp.LABEL,
										pdcp.code as code_PDCP,
										ecm.code as code_ECM,
										ecm.value as T_MAP_REF,
										fl.path
									from
										"&T_PATH_EGP_PARSED\parent_details_code_parent.sas7bdat" as pdcp
											left join "&T_PATH_EGP_PARSED\embedded_code_map.sas7bdat" as ecm
												on pdcp.code=ecm.code
											left join "&T_PATH_EGP_FILELIST.\filelist_sci.sas7bdat" as fl
												on find(reverse(strip(fl.path)),reverse(strip(ecm.value)),'i')=1
									where
										pdcp.L_EMBEDDED='TRUE'
									order by
										pdcp.LABEL
								;
							quit;
							%if %eval(&SQLOBS.>0) %then %do;
									data _NULL_;
										set "&T_PATH_EGP_PARSED.\EMBEDDED_CODE.sas7bdat" end=eof;
										length T_LABEL_PREV $256;
										format T_LABEL_PREV $256.;
										length O_INDEX 8;
										format O_INDEX 8.;
										retain T_LABEL_PREV;
										retain O_INDEX;
										if _N_=1 then do;
												T_LABEL_PREV="";
												O_INDEX=0;
											end;
										if strip(T_LABEL_PREV)=strip(LABEL) then do;
												O_INDEX=O_INDEX+1;
												LABEL=catx("_",strip(LABEL),cats("C",strip(O_INDEX)));
											end;
										else do;
												O_INDEX=0;
												T_LABEL_PREV=strip(LABEL);
											end;
										call symput("T_CODE_PATH_SOURCE_"||strip(_N_),catx("\",PATH,"code.sas"));
										call symput("T_CODE_PATH_TARGET_"||strip(_N_),catx("\","&T_PATH_EXTRACT_FINAL.",cats(LABEL,".sas")));
										if eof then call symput("N_CODE",_N_);
									run;quit;
									%do code_idx=1 %to &N_CODE.;
											%sysexec copy "&&T_CODE_PATH_SOURCE_&code_idx.." "&&T_CODE_PATH_TARGET_&code_idx..";
										%end;
								%end;

							%sysexec copy "&T_PATH_EGP_XML_PARSED.\xml_parsed.sas7bdat" "&T_PATH_EGP_CODE.\xml_parsed.sas7bdat";
							%sysexec rmdir /S /Q "&T_PATH_UNZIPPED.";
							%sysexec rmdir /S /Q "&T_PATH_EGP_PARSED.";
							%sysexec rmdir /S /Q "&T_PATH_EGP_FILELIST.";
							%sysexec rmdir /S /Q "&T_PATH_EGP_ZIP.";

							%let LRP_DONE_&O_PROCESS_FREE.=1;
							%m_leave:
								%put leaving !!!;
								%if %eval(&&LRP_DONE_&O_PROCESS_FREE..>1) %then %do;
										filename LOG_E "&T_PATH_EXTRACT_FINAL.\ERROR.log";
										proc printto log=LOG_E new;
										run;quit;
										%put OBJ_EGP: &T_PATH_EGP_SRCE.\&T_NAME_EGP_SRCE..egp;
										%put ERROR_CODE: &&LRP_DONE_&O_PROCESS_FREE..;
										%put DESCRIPTION: &&T_ETXT_&O_PROCESS_FREE..;
										proc printto log=LOG_RP;
										run;quit;
										filename LOG_E clear;
									%end;
								proc printto;
								run;quit;
								filename LOG_RP clear;

					%mend;
					%EMBEDDED_CODE_EXTRACT;
					/*%nrstr(%sysrput L_DONE_&O_PROCESS_FREE.=&&LRP_DONE_&O_PROCESS_FREE..;)*/
					%nrstr(%sysrput L_DONE_&O_PROCESS_FREE.=1;)
			endrsubmit;
			/* wait for free remote process */
			/*%if %eval(&o.<&N_OBJ_EGP.) %then %do;
				%end;*/
		%end;		

	%put Loop completed %sysfunc(datetime(),datetime20.);
	/* signoff remote processes */
	%let N_ATTEMPT=0;
	%let L_ALL_DONE=0;
	%do %while(%eval(&N_Attempt.<20) and %eval(&L_ALL_DONE.=0));
			%let session_idx=1;
			%let N_ATTEMPT=%eval(&N_ATTEMPT.+1);
			%let L_ALL_DONE=1;
			%if %eval(&&L_DONE_&session_idx.^=1) %then %do;
					%put L_DONE_&session_idx.: &&L_DONE_&session_idx.;
					%put RPROC_&session_idx. still busy;
					/*%put OBJ_EGP_&session_idx.: &&OBJ_EGP_&session_idx..;*/
					%let L_ALL_DONE=0;
				%end;
			%if %eval(&L_ALL_DONE.=0) %then %do;
					%let rc=%sysfunc(sleep(15));
				%end;
		%end;
	/*waitfor _all_ &T_PROCESSES_LST.;*/

	%let C_SIGNOFF=2;
	%goto RP_SIGNOFF;
	%RP_SIGNOFF_DONE_2:
	%put Sign of completed %sysfunc(datetime(),datetime20.);

/* main procedure completed */
%goto m_leave;


/* subs */
%REMOTE_PREPARE:
		%put NOTE: ******************************************************;
		%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects started;
		%put NOTE:			Start initializing remote processes;
		%put NOTE: ******************************************************;
		%put ;

	/* prepare remote processes */
		/* set remote sas */
		options sascmd='f:\sas\sashome\Sasfoundation\9.3\sas.exe -nosyntaxcheck';

		/* initialize remote sessions */
		%let L_SIGNONS_OK=0;
		%let N_SIGNONS_ATTEMPTS=0;
		%let T_PROCESSES_LST=;
		%do session_idx=1 %to 8;
				%let L_RPROC_&session_idx._SO_OK=0;
				%let T_RPROC_&session_idx._NAME=RPROC_&session_idx.;
				%global L_DONE_&session_idx.;
			%end;
		%do %while(%eval(&L_SIGNONS_OK.=0) and %eval(&N_SIGNONS_ATTEMPTS.<5));
				%let L_SIGNONS_OK=1;
				%do session_idx=1 %to 8;
						%if %eval(&&L_RPROC_&session_idx._SO_OK=0) %then %do;
								%let L_RPROC_&session_idx._SO_OK=1;
								%let T_MACV_SIGNON=L_&&T_RPROC_&session_idx._NAME.;
								%put signon &&T_RPROC_&session_idx._NAME. - macvar: &T_MACV_SIGNON.;
								filename junk dummy;
								proc printto log=junk;
								run;quit;

								signon &&T_RPROC_&session_idx._NAME. macvar=&T_MACV_SIGNON.;
								%let rc=sysfunc(sleep(10));
								proc printto;
								run;quit;

								%put signon &&T_RPROC_&session_idx._NAME. - macvar: &T_MACV_SIGNON.: &&&T_MACV_SIGNON..;

								%let L_WAIT=1;
								%do %while(%eval(&L_WAIT.>0));
										%if %eval(&&&T_MACV_SIGNON..=1) %then %do;
												%let L_RPROC_&session_idx._SO_OK=0;
												%let L_SIGNONS_OK=0;
												%let L_WAIT=0;
												%put signon &&T_RPROC_&session_idx._NAME.;
											%end;
										%else %if %eval(&&&T_MACV_SIGNON..=3) %then %do;
												%let rc=%sysfunc(sleep(10));
											%end;
										%else %do;
												%let T_PROCESSES_LST=&T_PROCESSES_LST. &&T_RPROC_&session_idx._NAME.;
												%let L_DONE_&session_idx.=1;
												%put L_DONE_&session_idx.: &&L_DONE_&session_idx.;
												%let L_WAIT=0;
											%end;
									%end;
							%end;
					%end;
			%end;

		%if %eval(&L_SIGNONS_OK.=0) %then %do;
				%put ERROR: ******************************************************;
				%put ERROR: Something went wrong with remote processing.;
				%put ERROR: This is fatal for the procedure, so it will be terminated;
				%put ERROR:	after attempt to clean sign off potential running remote processes;
				%put ERROR: ******************************************************;
				%put ;
				%let C_SIGNOFF=1;
				%goto RP_SIGNOFF;
				%RP_SIGNOFF_DONE_1:
				%abort cancel;
			%end;
		%else %do;
				%put NOTE: ******************************************************;
				%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects started;
				%put NOTE:			Finished initializing remote processes;
				%put NOTE: ******************************************************;
				%put ;
			%end;
	%goto REMOTE_PREPARE_DONE;

%FREE_PROCESS:
		/* determine free proces */
		%let O_PROCESS_FREE=0;
		%let O_PROCESS_IDX=1;
		%let L_FREE_FOUND=0;
		%let N_FREE_PROCESS_ATTEMPT=0;
		/* wait for any process completed */
		waitfor _any_ &T_PROCESSES_LST.;
		/* determine which process has been completed, by checking all remote processes */
		/* when no free process is found, wait for 10 seconds before retrying, */
		/* to deal with possible delay in updating local variable L_DONE_&PROCESS_IDX. */
		/* Reattempt maximum 20 times, when still no free process found, */
		/* Very likely something goes wrong with communication between remote and local process */
		%do %while(%eval(&L_FREE_FOUND.=0) and %eval(&N_FREE_PROCESS_ATTEMPT.<20));
				%put L_DONE_&O_PROCESS_IDX.: &&L_DONE_&O_PROCESS_IDX.;
				%if %eval(&&L_DONE_&O_PROCESS_IDX.=1) %then %do;
						%put L_DONE_&O_PROCESS_IDX.: &&L_DONE_&O_PROCESS_IDX.;
						%let O_PROCESS_FREE=&O_PROCESS_IDX.;
						%let L_FREE_FOUND=1;
					%end;
				%if %eval(&L_FREE_FOUND.=0) %then %do;
						%if %eval(&O_PROCESS_IDX.=8) %then %do;
								%let N_FREE_PROCESS_ATTEMPT=%eval(&N_FREE_PROCESS_ATTEMPT.+1);
								%let rc=%sysfunc(sleep(10));
								%let O_PROCESS_IDX=1;
							%end;
						%else %do;
								%let O_PROCESS_IDX=%eval(&O_PROCESS_IDX.+1);
							%end;
					%end;
			%end;
		%put ;
	%goto FREE_PROCESS_DONE;

%RP_SIGNOFF:
		%put NOTE: ******************************************************;
		%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
		%put NOTE:			Start signing off remote processes;
		%put NOTE: ******************************************************;
		%put ;
		%do session_idx=1 %to 8;
				%if %eval(&&L_RPROC_&session_idx._SO_OK>0) %then %do;
						%put signing off process &&T_RPROC_&session_idx._NAME.;
						killtask &&T_RPROC_&session_idx._NAME.;
						signoff &&T_RPROC_&session_idx._NAME.;
					%end;
			%end;
		%put NOTE: ******************************************************;
		%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
		%put NOTE:			Finshed signing off remote processes;
		%put NOTE: ******************************************************;
		%put ;

	%if %eval(&C_SIGNOFF.=1) %then %goto RP_SIGNOFF_DONE_1;
	%else %if %eval(&C_SIGNOFF.=2) %then %goto RP_SIGNOFF_DONE_2;
/* end subs */

%m_leave:
	%put NOTE: ******************************************************;
	%put NOTE: %sysfunc(strip(%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.))) : Macro compressed objects;
	%put NOTE:		Macro completed;
	%put NOTE: ******************************************************;
	%put ;
%mend;


%macro SAS_CODE_INVENTARIS
	(
	T_PATH_MACROS=,
	T_PATH=,
	T_DS_OUT_PATH=,
	T_DS_OUT_NAME=
	)
	/parmbuff minoperator
	;
/* prep - to review when finalizing */

	%local T_PATH_SCI;
	%local T_DS_OUT_PATH_SCI;

	%let T_PATH_SCI=&T_PATH.;
	%let T_DS_OUT_PATH_SCI=&T_DS_OUT_PATH.;



	%include "&T_PATH_MACROS.\SAS_INVENTARIS\GET_FILE_LIST_20160925.sas";
	%include "&T_PATH_MACROS.\MACROS_GENERAL\SASZip_Lite.sas";

	proc printto;
	run;quit;
/* end prep */
	%Compressed_objects
		(
		T_PATH_MACROS=&T_PATH_MACROS.,
		T_PATH_SOURCE=&T_PATH_SCI.,
		T_PATH_TARGET=&T_DS_OUT_PATH_SCI.

		)
		;
	
/* compressed obects */

/* end compressed objects */
	

/* base procedure completed */
%goto m_leave;

/* subs */

/* end subs */

%m_leave:

%mend;
