%macro PARSE_EG_PROJECT_XML
				(
				T_EG_PROJECT_FULL_PATH=,
				T_MAP_OUT_FULL_PATH=,
				T_VAR_RETURN=O_RET,
				LOG=
				)
				;

/*
15/04/2017	: !!! still experimental

return code:
0: procedure completed succesfully
1: T_EG_PROJECT_FULL_PATH missing

*/
options noxwait xsync;
%let &T_VAR_RETURN.=0;

/* check paths */
	/* T_EG_PROJECT_FULL_PATH */
	%if %sysevalf(%superq(T_EG_PROJECT_FULL_PATH)=,boolean)^=0 %then %do;
			%let &T_VAR_RETURN.=1;
			%put ERROR: required variable 'T_EG_PROJECT_FULL_PATH' is missing;
			%goto m_leave;
		%end;
	%else %do;
			%let T_EG_PROJECT_FULL_PATH=%sysfunc(strip(%sysfunc(dequote(&T_EG_PROJECT_FULL_PATH.))));
			%if %sysfunc(fileexist(&T_EG_PROJECT_FULL_PATH.))=0 %then %do;
					%let &T_VAR_RETURN.=2;
					%put ERROR: Variable 'T_EG_PROJECT_FULL_PATH', file does not exist;
					%put ERROR: &T_EG_PROJECT_FULL_PATH.;
					%goto m_leave;
				%end;
		%end;

	/* T_MAP_OUT_FULL_PATH */
	%if %sysevalf(%superq(T_MAP_OUT_FULL_PATH)=,boolean)^=0 %then %do;
			%let &T_VAR_RETURN.=3;
			%put ERROR: required variable 'T_MAP_OUT_FULL_PATH' is missing;
			%goto m_leave;
		%end;
	%else %do;
			%let T_MAP_OUT_FULL_PATH=%sysfunc(strip(%sysfunc(dequote(&T_MAP_OUT_FULL_PATH.))));
			%sysexec md "&T_MAP_OUT_FULL_PATH.";
			%if %sysfunc(fileexist(&T_MAP_OUT_FULL_PATH.))=0 %then %do;
					%let &T_VAR_RETURN.=4;
					%put ERROR: Variable 'T_MAP_OUT_FULL_PATH', map does not exist;
					%put ERROR: &T_MAP_OUT_FULL_PATH.;
					%goto m_leave;
				%end;
			libname L_OUT "&T_MAP_OUT_FULL_PATH.";
		%end;

%let Job_Started=%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.);

/* set filename ref for xml source */
filename XML_SRC "&T_EG_PROJECT_FULL_PATH";

/* put raw lines in temporary dataset to create a log containing usable text */
%let TXT_RAW=%sysfunc(pathname(work))\tmp_xml.txt;
proc printto log="&TXT_RAW." new;
run;quit;
options linesize=256;
data work.Projext_TXT;
	informat line $1024.;
	infile XML_SRC dsd dlm='0D'x lrecl=1024;
	list;
	input line;
run;quit;

/* parse lines and xml parameters from created log/text file */
options linesize=80;
proc printto log=&LOG.;
run;quit;
filename XML_SRC clear;
filename XML_SRC "&TXT_RAW.";
data work.LOAD_XML (keep=ID LINE_CLN); 
	informat  ID 8. line_cln $510. line $1024. log_line $1024. LINE_PARSE $1024.;
	infile XML_SRC dsd dlm='0D'x lrecl=1024;
	retain XML_STARTED 0;
	retain LINE_PARSE '';
	retain LINE_CONTINUED 0;
	retain ID 0;

	SAS_LINE=0;
	input log_line;
	line=upcase(log_line);
	if missing(line)=0 then do;
			if XML_STARTED=0 and prxmatch("/^\d+\s+<\?XML\s+.*/",line)>0 then XML_STARTED=1;
			if XML_STARTED=1 and prxmatch("/^NOTE/",line)>0 then XML_STARTED=0;
			if XML_STARTED=1 then do;
					if prxmatch("/(^\f\d+)|(^RULE)|(^ZONE\s+\s+)|(^NUMR\s+\s+)|(\d+\s+THE SAS SYSTEM)/",line)>0 then do;
								SAS_LINE=1;
								/*put 'sas-line: ' line;*/
							end;
					if SAS_LINE=0 then do;
							if LINE_CONTINUED=1 then do;
									x=cats('*',line,'*');
									/*put 'line continued: ' x;*/
									prev_line=_N_-1;
									if prxmatch("/^\d+\s+.*$/",line)>0 then do;
											line=prxchange("s/(^\d+\s+)(.*$)/$2/",-1,line);
										end;
								end;							
							if prxmatch("/\s+\d+$/",trim(line))=0 then LINE_CONTINUED=1;
							else LINE_CONTINUED=0;
							LINE_PARSE=cats(LINE_PARSE,LINE);
							if LINE_CONTINUED=0 then do;
									ID=ID+1;
									line_cln=prxchange("s/\s+\d+$//",-1,prxchange("s/^[\s\.]*//",-1,strip(substr(LINE_PARSE,11))));
									if prxmatch("/^.*<\d+\s+.+\w+>$/",trim(line_cln))>0 then do;
											line_cln=prxchange("s/(^.*<)(\d+\s+)(\w+>$)/$1$3/",-1,trim(line_cln));
										end;
									output;
									LINE_PARSE='';
								end;
						end;
				end;
		end;
run;quit;				

/* cleanup already redundant files */
filename XML_SRC clear;
%sysexec del &TXT_RAW.;
proc datasets library=work nodetails nolist;
   delete Projext_TXT;
run;quit;

/* deal with xml-tags */
data work.TAGS_XML;
	informat ID 8. PREV_LEVEL 8. LEVEL_X 8. PARENT $1024. TAG $60. Value $250.;
	set work.LOAD_XML end=eof;
	retain LEVEL_X 0;
	retain PARENT;
	retain TAG_PREV;
	if _N_=1 then PARENT='ROOT';

	TYPE_V=.;
	TYPE_O=.;
	TYPE_C=.;
	TYPE_E=.;
	TAG='';
	VALUE='';
	
	PREV_LEVEL=LEVEL_X;
	extra=0;
	line_cln=upcase(line_cln);
	/* TAGS */
		/* prolog */
		if prxmatch("/^<\?XML\s+/",trim(line_cln))>0 then do;
				TYPE_O=1;
				LEVEL_X=LEVEL_X+1;
				TAG='<XML>';
				PARENT=catx(' ',PARENT,TAG,ID);
				output;
				LEVEL_X=LEVEL_X+1;
				TAG="<TAG_ATTRIBUTE>";
				PARENT=catx(' ',PARENT,TAG,ID);
				output;
				TYPE_O=.;
				TYPE_V=1;
				LEVEL_X=LEVEL_X+1;
				VALUE=upcase(trim(prxchange("s/(^<\?[A-Z]+)(\s+.*)(\?>$)/$2/",-1,trim(line_cln))));
				output;
				LEVEL_X=LEVEL_X-1;
				TYPE_V=.;
				TYPE_C=1;
				TAG="</TAG_ATTRIBUTE>";
				VALUE='';
				output;
				PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,strip(PARENT));
				LEVEL_X=LEVEL_X-1;
				TAG="</XML>";
				output;
				LEVEL_X=LEVEL_X-1;
				PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,strip(PARENT));
			end;
		/* root */
		else if prxmatch("/^<PROJECTCOLLECTION\s{1}/",trim(line_cln))>0 then do;
				LEVEL_X=LEVEL_X+1;
				TYPE_O=1;
				TAG="<PROJECTCOLLECTION>";
				PARENT=catx(' ',PARENT,TAG,ID);
				output;
				LEVEL_X=LEVEL_X+1;
				TAG="<TAG_ATTRIBUTE>";
				PARENT=catx(' ',PARENT,TAG,ID);
				output;
				TYPE_O=.;
				TYPE_V=1;
				LEVEL_X=LEVEL_X+1;
				VALUE=upcase(trim(prxchange("s/(^<[A-Z]+\s+)(.*)(>$)/$2/",-1,trim(line_cln))));
				output;
				LEVEL_X=LEVEL_X-1;
				TYPE_V=.;
				TYPE_C=1;
				TAG="</TAG_ATTRIBUTE>";
				VALUE='';
				output;
				PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,strip(PARENT));
				LEVEL_X=LEVEL_X-1;
				PARENT=prxchange("s/(^.+)(\s<\w+>$)\s\d+/$1/",-1,strip(PARENT));
			end;
		/* children*/
		else do;
				/* opening tag */
				if prxmatch("/^<\w.*>.*/",trim(line_cln))>0 then do;
						LEVEL_X=LEVEL_X+1;
						TYPE_O=1;
						TYPE_C=.;
						TYPE_V=.;
						TAG=upcase(trim(prxchange("s/(^<)(\w+)(.*)(>.*)/<$2>/",-1,trim(line_cln))));
						TAG_PREV=TAG;
						PARENT=catx(' ',PARENT,TAG,ID);;
						VALUE='';
						output;
					end;
				/* !!! opening tag self closing  */
				if prxmatch("/^<\w+\s+\/>.*/",trim(line_cln))>0 then do;
						/*put 'self closing';*/
						/* value */
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						VALUE='';
						TAG=upcase(trim(prxchange("s/(^<)(\w+)(\s+\/>$)/<$2>/",-1,trim(line_cln))));
						output;
						LEVEL_X=LEVEL_X-1;
						/* closing tag */
						TYPE_O=.;
						TYPE_C=1;
						TYPE_V=.;
						VALUE='';
						TAG=upcase(trim(prxchange("s/(^<)(\w+)(\s+\/>$)/<\/$2>/",-1,trim(line_cln))));
						output;
						PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,trim(PARENT));
						LEVEL_X=LEVEL_X-1;
					end;
				/* attributes */
				if prxmatch("/^<\w+\s+.{2,}>.*/",trim(line_cln))>0 then do;
						/* attributes */
						LEVEL_X=LEVEL_X+1;
						TYPE_O=1;
						TYPE_C=.;
						TYPE_V=.;
						TAG="<TAG_ATTRIBUTE>";
						TAG_PREV=TAG;
						PARENT=catx(' ',PARENT,TAG,ID);
						VALUE='';
						output;
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						TAG=TAG_PREV;
						VALUE=upcase(trim(prxchange("s/(^<)(\w+\s+)(.{2,})(>)(.*)/$3/",-1,trim(line_cln))));
						output;
						LEVEL_X=LEVEL_X-1;
						TYPE_O=.;
						TYPE_C=1;
						TYPE_V=.;
						VALUE='';
						TAG="</TAG_ATTRIBUTE>";
						output;
						PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,strip(PARENT));
						LEVEL_X=LEVEL_X-1;
					end;
				/* value */
				if prxmatch("/^<\w+.*>.+<\/\w+>$/",trim(line_cln))>0 then do;
						/*put 'tag-value-tag';*/
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						VALUE=upcase(trim(prxchange("s/(^<\w+.*>)(.+)(<\/\w+>$)/$2/",-1,trim(line_cln))));
						TAG=upcase(trim(prxchange("s/(^<)(\w+)(.*>)(.+)(<\/\w+>$)/<$2>/",-1,trim(line_cln))));
						output;
						LEVEL_X=LEVEL_X-1;
					end;
				else if prxmatch("/^<\w+.*>.+$/",trim(line_cln))>0 then do;
						/*put 'tag-value';*/
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						VALUE=upcase(trim(prxchange("s/(^<\w+.*>)(.+$)/$2/",-1,trim(line_cln))));
						TAG=upcase(trim(prxchange("s/(^<)(\w+)(.*>)(.+$)/<$2>/",-1,trim(line_cln))));
						output;
						LEVEL_X=LEVEL_X-1;
					end;
				else if prxmatch("/^.+<\/\w+>$/",trim(line_cln))>0 then do;
						/*put 'value-tag';*/
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						VALUE=upcase(trim(prxchange("s/(^.+)(<\/\w+>$)/$1/",-1,trim(line_cln))));
						TAG=upcase(trim(prxchange("s/(.+)(<\/)(\w+)(>$)/<$3>/",-1,trim(line_cln))));
						output;
						LEVEL_X=LEVEL_X-1;
					end;
				else if prxmatch("/(^<\w+.*>)|(<\/\w+>)/",trim(line_cln))=0 then do;
						/*put 'value';*/
						LEVEL_X=LEVEL_X+1;
						TYPE_O=.;
						TYPE_C=.;
						TYPE_V=1;
						VALUE=trim(line_cln);
						TAG=TAG_PREV;
						output;
						LEVEL_X=LEVEL_X-1;
					end;
				/* closing tag */
				if prxmatch("/.*<\/\w+>$/",trim(line_cln))>0 then do;
						TYPE_O=.;
						TYPE_C=1;
						TYPE_V=.;
						TAG=upcase(trim(prxchange("s/(.+)(<\/\w+>$)/$2/",-1,trim(line_cln))));
						VALUE='';
						output;
						PARENT=prxchange("s/(^.+)(\s<\w+>\s\d+$)/$1/",-1,trim(PARENT));
						LEVEL_X=LEVEL_X-1;
					end;
			end;

run;

/* clean parsed xml */
proc sql;
	create table L_OUT.XML_PARSED as
		select distinct
			base.ID,
			base.PARENT,
			base.TAG,
			base.VALUE
		from
			work.TAGS_XML as base
		where
			base.TYPE_V=1
		order by
			base.ID
	;
quit;


/* find embeded code */
	/* find code elements */
	proc sql;
		create table work.TYPE_CODE_TASK as
			select distinct
				strip(prxchange("s/(.+)(\s<TAG_ATTRIBUTE>.+)/$1/",-1,base.parent)) length=256 format=$256. as PARENT
			from
				L_OUT.XML_PARSED as base
			where
				base.TAG="<TAG_ATTRIBUTE>"
				and
				base.Value contains 'CODETASK';
		;
	quit;

	/* discriminate embedded and not embedded */
	proc sql;
	   create table work.Parent_Details_Embedded as 
	   	select distinct
				base.PARENT,
				lu.TAG, 
				lu.Value as L_EMBEDDED
	      from 
				work.TYPE_CODE_TASK as base,
				L_OUT.XML_PARSED as lu
			where
				(
				lu.parent contains catx(' ',strip(base.parent),"<CODETASK>")
				and 
				strip(lu.TAG)="<EMBEDDED>"
				)
			order by
				base.parent,
				lu.parent
		;
	quit;

	/* determine codetask */
	proc sql;
	   create table work.Parent_Details_INCLUDEWRAPPER as 
	   	select distinct
				base.PARENT,
				base.L_EMBEDDED,
				lu.TAG,
				lu.Value as L_INCLUDEWRAPPER
	      from 
				work.Parent_Details_Embedded as base,
				L_OUT.XML_PARSED as lu
			where
				(
				lu.parent contains catx(' ',strip(base.parent),"<CODETASK>")
				and 
				strip(lu.TAG)="<INCLUDEWRAPPER>"
				)
			order by
				base.parent,
				lu.parent
		;
	quit;

	/* get label code element */
	proc sql;
	   create table work.Parent_Details_LABEL as 
	   	select distinct
				base.PARENT,
				base.L_EMBEDDED,
				base.L_INCLUDEWRAPPER,
				lu.tag,
				lu.value as LABEL
	      from 
				work.Parent_Details_INCLUDEWRAPPER as base,
				L_OUT.XML_PARSED as lu
			where
				(
				lu.parent contains catx(' ',strip(base.parent),"<ELEMENT>")
				and 
				lu.TAG="<LABEL>"
				)
			order by
				base.parent,
				lu.parent
		;
	quit;

	/* get code reference, only for embedded code */
	proc sql;
	   create table work.Parent_Details_CODE as 
	   	select distinct
				base.PARENT,
				base.L_EMBEDDED,
				base.L_INCLUDEWRAPPER,
				base.LABEL,
				lu.parent as parent_lu,
				lu.tag,
				lu.value as CODE
	      from 
				work.Parent_Details_LABEL as base,
				L_OUT.XML_PARSED as lu
			where
				(
				/*lu.parent contains catx(' ',strip(base.parent),"<SUBMITABLEELEMENT>")
				and*/
				lu.parent contains strip(base.parent)
				and
				lu.TAG="<CODE>"
				and
				lu.VALUE is not missing
				)
			order by
				base.parent,
				lu.parent
		;
	quit;

	/**/
	proc sql;
		create table L_OUT.PARENT_DETAILS_CODE_PARENT as 
			select distinct
				base.PARENT, 
				prxchange("s/(.+)(\s+<ELEMENT>\s+\d+)(\s<ID>\s+\d+)/$1/",-1,strip(lu.Parent)) as  CODE_PARENT,
				base.L_EMBEDDED, 
				base.L_INCLUDEWRAPPER, 
				base.LABEL, 
				base.CODE
			from
				work.PARENT_DETAILS_CODE as base
					left join L_OUT.XML_PARSED as lu
						on (base.CODE = lu.Value)
			where
				lu.tag="<ID>"
		;
	quit;

	/**/
	proc sql;
		create table L_OUT.EMBEDDED_CODE_MAP as 
			select distinct
				base.PARENT, 
				base.CODE_PARENT,
				base.L_EMBEDDED, 
				base.L_INCLUDEWRAPPER, 
				base.LABEL, 
				base.CODE,
				lu.id,
				lu.parent as parent_lu,
				lu.TAG as TAG,
				lu.value
			from
				L_OUT.PARENT_DETAILS_CODE_PARENT as base
					left join L_OUT.XML_PARSED as lu
						on lu.parent contains strip(base.code_parent)
			where
				lu.TAG="<PARENT>"
			order by
				base.parent,
				base.CODE_PARENT,
				lu.id
		;
	quit;


%m_leave:
	libname L_OUT clear;
	%let Job_completed=%sysfunc(date(),worddate.) %sysfunc(time(),timeampm.);
	%put Job started at &Job_Started.;
	%put Job completed at &Job_completed.;
%mend;

/*
%global PARSE_EG_PROJECT_XML_OK;
%PARSE_EG_PROJECT_XML
		(
		T_EG_PROJECT_FULL_PATH=\\srsasd1\sasdata\Users\HSP\EGuide\SAS_CODE_INVENTARIS\project.xml,
		T_MAP_OUT_FULL_PATH=\\srsasd1\sasdata\Users\HSP\EGuide\SAS_CODE_INVENTARIS\TEST_20170415\TMP,
		T_VAR_RETURN=PARSE_EG_PROJECT_XML_OK
		)
		;
%put ;
%put PARSE_EG_PROJECT_XML_OK: &PARSE_EG_PROJECT_XML_OK.;
*/
