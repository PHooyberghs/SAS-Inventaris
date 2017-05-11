%macro SASZip_Lite(zip=, sfdr=, fstyl=%str(*.sas*dat), tfdr=,overwrite=N,create_extra=N,T_VAR_DESTINATION_RET=);
	/* adapted from source : http://support.sas.com/resources/papers/proceedings12/057-2012.pdf */
	/****************************************************************
	The code posted below is provided "AS IS" with NO WARRANTIES.
	ZIP: directory and file name of zip archive
	SFDR: directory of source files (to be zipped)
	FSTYL: File type of source files; value: *.* as "zip a folder" 
	TFDR: Target directory for unzipped files (for unzip) 
	*****************************************************************/

	%local zip sfdr fstyl tfdr vbadir p q mode;

	/* set path for vbs-script to work to avoid user rights conflicts */
	%let PATH_VBS=%sysfunc(pathname(work));
	/* Set up a temporary working folder for VBScript */
	/*%let vbsdir=c:\MyZi$Dir;*/
	%let vbsdir=&PATH_VBS.\VBS;
	options noxwait xsync;

	%if %sysevalf(%superq(tfdr)=,boolean)=0 %then %do;
			%put UNZIP;
			/* mode unzip */
			%let MODE=U;
			%if %sysfunc(fileexist("&zip."))=1 %then %do;
					/* overwrite or create new unzipfolder ? */
					%if %sysfunc(fileexist("&tfdr."))=1 %then %do;
							/* check if folder is empty */
							%let &t_var_destination_ret.=&tfdr.;
							%let folderpath=&tfdr.;
							%let FE_RET=UBase;
							%goto check_folder_empty;
							%FE_RET_UBASE:
							%if &L_FOLDER_EMPTY.=N %then %do;
									/* when folder not empty */
									%if %sysfunc(dequote(&overwrite.))=Y %then %do;
											%sysexec rd /s/q "&tfdr.";
											%sysexec md "&tfdr.";
										%end;
									%else %do;
											%if %sysfunc(dequote(&create_extra.))=Y %then %do;
													%let Index=1;
													%let Done=N;
													%do %while(&DONE.=N);
															%let tfdr_tmp=&tfdr._&Index.;
															%if %sysfunc(fileexist("&tfdr_tmp."))=1 %then %do;
																	%let folderpath=&tfdr_tmp.;
																	%let FE_RET=UIndex;
																	%goto check_folder_empty;
																	%FE_RET_UIndex:
																	%if &L_FOLDER_EMPTY.=N %then %do;
																			%let INDEX=%eval(&INDEX.+1);
																		%end;
																	%else %do;
																			%let DONE=Y;
																		%end;
																%end;
															%else %do;
																	%let DONE=Y;
																%end;
														%end;
													%sysexec md "&tfdr_tmp.";
													%put NOTE: Destination folder "&tfdr." already exists;
													%put NOTE: folder "&tfdr_tmp." is created and will be used instead;
													%let tfdr=&tfdr_tmp.;
													%let &t_var_destination_ret.=&tfdr_tmp.;
												%end;
											%else %do;
													%put ERROR: destination folder already exists and neihter parameter overwrite or create_extra are set to Y;
													%put ERROR: failed to unzip to destination folder.;
													%goto leave;
												%end;
										%end;
								%end;
						%end;
				%end;
			%else %do;
					%put ERROR: the archive to unzip (&zip.) can not be found.;
					%put ERROR: unzip failed;
					%goto leave;
				%end;
		%end;
	%else %if %sysevalf(%superq(SFDR)=,boolean)=0 %then %do;
			%put ZIP;
			/* mode zip */
			%let MODE=Z;
			/* zip: overwrite or create new zipfolder ? */
			%if %sysfunc(fileexist("&tfdr."))=1 %then %do;
					%if %sysfunc(fileexist("&zip."))=1 %then %do;
							/* check if folder is empty */
							%let folderpath="&zip.";
							%let FE_RET=ZBase;
							%goto check_folder_empty;
							%FE_RET_ZBase:
							%if &L_FOLDER_EMPTY.=N %then %do;
									%if %sysfunc(dequote(&overwrite.))=Y %then %do;
											%sysexec rd /s/q "&zip.";
											%sysexec md "&zip.";
										%end;
									%else %do;
											%if %sysfunc(dequote(&create_extra.))=Y %then %do;
													%let Index=1;
													%let Done=N;
													%do %while(&DONE.=N);
															%let zip_tmp=&zip._&Index.;
															%if %sysfunc(fileexist("&zip_tmp."))=1 %then %do;
																	%let folderpath=&zip_tmp.;
																	%let FE_RET=ZIndex;
																	%goto check_folder_empty;
																	%FE_RET_ZIndex:
																	%if &L_FOLDER_EMPTY.=N %then %do;
																			%let INDEX=%eval(&INDEX.+1);
																		%end;
																	%else %do;
																			%let DONE=Y;
																		%end;
																%end;
															%else %do;
																	%let DONE=Y;
																%end;
														%end;
													%sysexec md "&zip_tmp.";
													%put NOTE: Destination folder "&zip." already exists;
													%put NOTE: folder "&zip_tmp." is created and will be used instead;
													%let zip=&zip_tmp.;
													%let &t_var_destination_ret.=&zip_tmp.;
												%end;
											%else %do;
													%put ERROR: destination folder already exists and neihter parameter overwrite or create_extra are set to Y;
													%put ERROR: failed to zip to destination folder.;
													%goto leave;
												%end;
										%end;
								%end;
						%end;
				%end;
			%else %do;
					%put ERROR: the folder conataining the files to zip (&SFDR.) can not be found.;
					%put ERROR: zip failed;
					%goto leave;
				%end;
		%end;
	%else %do;
			%put ERROR: ambigues or missing parameters, unable to determine the required action;
			%put ERROR: no zip or unzip performed;
			%goto leave;				
		%end;

	%put passed to kernel of task;

	
	
	/* To initiate a clean working space */
	%if %sysfunc(fileexist("&vbsdir"))=1 %then %sysexec rd /s/q "&vbsdir";
	%if %index(%upcase(&zip), .ZIP)=0 %then %let zip=&zip..zip;
	%let mode=;

	%if %length(&sfdr)>0 and (%length(&zip)>0) %then %do;
			/* Compress (zip) files */
			/* Extract directory name of the zip file, if no such folder, generate one */
			%let q=%sysfunc(tranwrd(&zip, %scan(&zip, -1, %str(\)), %str( )));
			%let q=%substr(&q, 1, %length(&q)-1);
			%if %sysfunc(fileexist("&q"))=0 %then %sysexec md "&q";
			
			/* Copy all requested files from a validated source folder to a temporary folder, and keep their original time stamps */
			%if %length(&sfdr)>0 and %sysfunc(fileexist("&sfdr"))=1 %then %do;
					%let mode=z;
					%sysexec md "&vbsdir";
					%if %qupcase(&fstyl)^=%str(*.*) %then %do;
							%sysexec md "&vbsdir.\temp_zip";
							%sysexec copy "&sfdr.\&fstyl" "&vbsdir.\temp_zip";
						%end;
				%end;
		%end;
	%else %if %length(&tfdr)>0 and %length(&zip)>0 and %sysfunc(fileexist("&zip"))>0 %then %do;
			/* Unzip files */
			%let mode=u;
			%sysexec md "&vbsdir";
		%end;
		
	%if &mode=z or &mode=u %then %do;
			/* Generate VBScript based on different modes */
			data _null_;
				FILE "&vbsdir.\xpzip.vbs";
				put 'Set ZipArgs = WScript.Arguments';
				put 'InputFile = ZipArgs(0)';
				put 'TgtFile = ZipArgs(1)';
				put 'Set objShell = CreateObject("Shell.Application")';
				put 'Set source = objShell.NameSpace(InputFile).Items';
				put 'soucnt = objShell.NameSpace(InputFile).Items.Count';
				%if &mode=z %then %do;
						put 'CreateObject("Scripting.FileSystemObject").CreateTextFile(TgtFile, True).Write "PK" & Chr(5) & Chr(6) & String(18, Chr(0))';
						put 'objShell.NameSpace(TgtFile).CopyHere(source)';
						put 'Do Until objShell.NameSpace(TgtFile).Items.Count = soucnt';
						put 'wScript.Sleep 3000';
						put 'Loop';
					%end;
				%else %do;
						put 'objShell.NameSpace(TgtFile).CopyHere(source)'; 
					%end;
				put 'wScript.Sleep 3000';
			run;
			
			/* Run VBScript file for data archiving */
			%if &mode=z %then %do;
					%if %qupcase(&fstyl)=%str(*.*) %then %do;
							%sysexec CScript "&vbsdir.\xpzip.vbs" "&sfdr" "&zip";
						%end;
					%else %do;
							%sysexec CScript "&vbsdir.\xpzip.vbs" "&vbsdir.\temp_zip" "&zip";
						%end;
				%end;
			%else %do;
					%sysexec CScript "&vbsdir.\xpzip.vbs" "&zip" "&tfdr";
				%end;
		%end;

	/* base procedure completed */
	%goto leave;

	%check_folder_empty:
			/* adapted from: http://www.sascommunity.org/wiki/SAS_Filesystem_Toolbox */
			Data _NULL_;
				rc=FILENAME('FMyRep',"&FolderPath");
				did=DOPEN('FMyRep');
				memcnt=DNUM(did);
				if memcnt>0 then call symput("L_FOLDER_EMPTY","N");
				else call symput("L_FOLDER_EMPTY","Y");
				rc=DCLOSE(did);
				rc=FILENAME('FMyRep');
		 	Run;
			%if &FE_RET.=UBase %then %goto FE_RET_UBase;
			%else %if &FE_RET.=UIndex %then %goto FE_RET_UIndex;
			%else %if &FE_RET.=ZBase %then %goto FE_RET_ZBase;
			%else %if &FE_RET.=ZIndex %then %goto FE_RET_ZIndex;
			%else %goto leave;

	%leave:	
	/* Clean up */
	%if %sysfunc(fileexist("&vbsdir"))=1 %then %sysexec rd /s/q "&vbsdir";



%mend SASZip_Lite;



/*%SASZip_Lite(zip=\\srsasd1\sasdata\Users\HSP\EGuide\CADASTER_001\DATA\REG_CONV_REG_TMP\input.ZIP,
				sfdr=\\srsasd1\sasdata\Users\HSP\EGuide\CADASTER_001\DATA\REG_CONV_REG_TMP\Input,
				fstyl=*.*,
				tfdr=,
				overwrite=Y,
				create_extra=N
				);*/	

/*
%SASZip_Lite(zip=\\srsasd1\sasdata\Users\HSP\EGuide\SAS_CODE_INVENTARIS\TEST_20170414\TMP_EGP_UZ\codesamples.zip,
				sfdr=,
				fstyl=*.*,
				tfdr=\\srsasd1\sasdata\Users\HSP\EGuide\SAS_CODE_INVENTARIS\TEST_20170414\TMP_EGP_UZ\codesamples,
				overwrite=Y,
				create_extra=N
				);
*/