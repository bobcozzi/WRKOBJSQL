      *******************************************************
      * Program name: Work with SQL Objects
      * Date        : 01 March 2021
      * Author      : R. Cozzi, Jr.
      *               Maintenance log
      *               ================
      *               Switched to all "native" interfaces
      *               Now include all SQL objects (sequence, indexes, etc)
      *               Corrected logical parms on call to Generate_SQL.
      *******************************************************
       CTL-OPT
           copyright('(c) 2021 by R. Cozzi, Jr. All Right Reserved.')
      /IF DEFINED(*CRTBNDRPG)
           ACTGRP(*NEW)
      /ENDIF
           OPTION(*NODEBUGIO:*SRCSTMT)
           EXTBININT(*YES) FIXNBR(*ZONED:*INPUTPACKED);

       dcl-f WRKOBJSQL workstn sfile(detail:RRN) indds(INDDS) infds(WSDS)
                             sfile(punchList:confirmRRN);

      /INCLUDE COZTOOLSRC/qcpysrc,fKeys

           dcl-ds psds Qualified psds;
             pgmName *PROC;
           end-ds;
           dcl-ds wsds Qualified;
            fKey   char(1) pos(369);
            sflRRN int(5)  pos(378);
           end-ds;

           dcl-ds indds Qualified;
             funcSFLCTL ind pos(21);
             funcSFL    ind pos(22);
             confirmCTL ind pos(31);
             confirmSFL ind pos(32);
             change    ind pos(71);
             Func      ind pos(41);
             Proc      ind pos(42);
             dupSearch ind pos(82);
           end-Ds;

           dcl-ds ds Qualified Inz;
             ORIGIN   VARCHAR(10);
             LANG     VARCHAR(10);
             PARMS    VARCHAR(16);
             PARMCNT  INT(5);
             DETERM   VARCHAR(32);
             SQLOBJTYPE VARCHAR(18);
             FNTYPE   VARCHAR(8);
             RTNLIB   VARCHAR(128);
             RTNNAME  VARCHAR(128);  // Function Name
             SPECLIB  VARCHAR(128);
             SPECNAME VARCHAR(128);  // Specific Func name
             TEXT     VARCHAR(50);
             EXTNAME  VARCHAR(279);  // System object (*SRVPGM or *PGM)
             CRTDATE  VARCHAR(10);

             iORIGIN   int(5);
             iLANG     int(5);
             iPARMS    int(5);
             iPARMCnt  int(5);
             iDETERM   int(5);
             iSQLOBJ   int(5);
             iFNTYPE   int(5);
             iRTNLIB   int(5);
             iRTNNAME  int(5);
             iSPECLIB  int(5);
             iSPECNAME int(5);
             iTEXT     int(5);
             iEXTNAME  int(5);
             iCRTDATE  int(5);
           end-ds;

           dcl-s X int(10);

           dcl-pr system  int(10) extProc('system');
             cmdString  pointer VALUE OPTIONS(*STRING:*TRIM);
           end-pr;
           dcl-pr QUSCMDLN  extPgm('QUSCMDLN') end-pr;
           dcl-pr sndmsg int(10) extProc(*CWIDEN:'Qp0zLprintf');
                outputPattern pointer value OPTIONS(*STRING);
                substitution1 pointer value OPTIONS(*STRING:*NOPASS);
                substitution2 pointer value OPTIONS(*STRING:*NOPASS);
                substitution3 pointer value OPTIONS(*STRING:*NOPASS);
                substitution4 pointer value OPTIONS(*STRING:*NOPASS);
                substitution5 pointer value OPTIONS(*STRING:*NOPASS);
                substitution6 pointer value OPTIONS(*STRING:*NOPASS);
                substitution7 pointer value OPTIONS(*STRING:*NOPASS);
                substitution8 pointer value OPTIONS(*STRING:*NOPASS);
           end-pr;
           dcl-pr sysCatalog extpgm('QSYS/QSQSQLCAT');
             options CHAR(32) Const;  // *FIX or *CHECK
           end-pr;

           dcl-ds QUSEC_t Qualified Template;
             bytes_Provided  int(10);
             bytes_RTN       int(10);
             msgid           char(7);
             reserved        char(1);
             msgdata         char(64);
           end-ds;
           dcl-ds QUSI0400_t Qualified Template;
             bytes_Rtn   int(10);
             bytes_Avail int(10);
             Job_Name    char(10);
             User_Name   char(10);
             Job_Number  char(6);
             Date_Sep    char(1) POS(219);
             Date_Format char(4) POS(220);
             Time_Sep    char(1) POS(300);
           end-ds;
           dcl-pr qusrjobAttr extpgm('QSYS/QUSRJOBI');
              rtnJobInfo  likeDS(QUSI0400_t);
              buffLen     int(10) Const;
              apiFmt      char(8) Const;
              job        char(36) Const;
              internal_Job char(16) Const;
              qusec       likeDS(QUSEC_t);
           end-pr;

           dcl-ds ec      LikeDS(QUSEC_T) Inz;

           dcl-s dateFmtEx varchar(10);

           dcl-s usrprf varchar(10) inz(*USER);

           dcl-s lastCSRPOS int(10);
           dcl-s lineCount int(10);

           dcl-s rrn    zoned(4:0);
           dcl-s csrpos zoned(4:0);
           dcl-s bRefresh   ind inz(*OFF);
           dcl-s confirmRRN zoned(4:0);
           dcl-s bConfirm   ind inz(*OFF);

           dcl-pi entryPlist EXTPGM('WRKOBJSQL');
             startupLib char(10) Const OPTIONS(*NOPASS);
             startupFn  CHAR(32) Const OPTIONS(*NOPASS);
           end-pi;

           *INLR = *ON;

           EXEC SQL SET OPTION COMMIT = *NONE,
                               NAMING = *SYS,
                               CLOSQLCSR = *ENDMOD;

           if (%Parms() >= %ParmNum(StartUpLib) and StartUpLib <> '');
             sSchema = %Trim(startUpLib);
           endif;
           if (%Parms() >= %ParmNum(StartUpFn) and StartUpFn <> '');
             sFunc = %Trim(startUpFn);
           endif;

           dateFmtEx = getJobInfo();

           confirmRRN = 0;
           indds.confirmSFL = *off;
           indds.confirmCTL = *off;
           write confirm;

           bRefresh = *ON;
           csrPos = 0;
           rrn    = 0;

           DOW (wsds.fKey <> F3);
            if (bRefresh or wsds.fKey = F5);
               if (sSchema = '*CURLIB');
                 exec sql values iquery.GETCURLIB() into :sSchema;
               endif;
               loadUDTF();
               if (lastCSRPOS > 0);
                  csrPos = lastCSRPOS;
               endif;
            else;
               if (lastCSRPOS > 0);
                 csrPos = lastCSRPOS;
               else;
                 csrpos = csrRRN;
               endif;
            endif;


           pgmname = psds.pgmname;
           if (csrpos <= 0 or csrpos > lineCount);
             csrpos = 1;   // Put Cursor on line 1 of subfile
           endif;

           bRefresh = *OFF;
           indds.funcSFLCTL = *on;
           indds.funcSFL = (lineCount > 0);
           write footer;

             ///////////////////////////////////////////////////////
             // Display the List of user profiles
             ///////////////////////////////////////////////////////
           exfmt Display;

           clear errMsg;

           if (wsds.fKey = F3);
             leave;
           endIf;

           if (wsds.fKey = F9);
             indds.DupSearch = NOT indds.DupSearch;
           endif;

           if (wsds.fKey = F6);
             sysCatalog('*CHECK');
             errmsg = 'SQL Catalog checked. Use F10=joblog for results';
             iter;
           endif;
           if (wsds.fKey = F8);
             sysCatalog('*FIX');
             errmsg = 'SQL Catalog fixed. Use F10=joblog for results';
             iter;
           endif;
           if (wsds.fKey = F10);
             system('dspjoblog');
             iter;
           endif;
           if (wsds.fKey = F21 or wsds.fKey = F22);
             quscmdln();
             iter;
           endif;

           if (indds.change);
             bRefresh = *ON;
           endIf;

                // Save the line number on which the Cursor is located
           if (indds.funcSFL);
              csrpos = wsds.SFLRRN;
           else;
              csrpos = 1;
           endif;

                // Process any line item Options entered by the User.
           IF  (wsds.fKey <> F3 and wsds.fKey <> F12 and lineCount > 0);
                // Read/process subfile options
              readc(e)  detail;
              dow NOT (%EOF() or %ERROR());
                 if (userOpt <> '' );
                   lastCSRPOS = RRN;
                 else;
                   lastCSRPOS = CSRRRN;
                 endif;
                 if (USEROPT = '2');  // Edit/Change
                    bRefresh = *ON;
                 elseif (USEROPT = '4'); // Drop (delete) the item
                    dropFn( FNSQLTYPE : fnSchema : fnSpecName);
                    bConfirm = *ON;
                 elseif (USEROPT = '5'); // Display SQL Source for this item
                    rtvsrc( FNSQLTYPE : fnSchema : fnSpecName : USEROPT);
                 elseif (USEROPT = '8'); // Edit SQL Source for this item
                    rtvsrc( FNSQLTYPE : fnSchema : fnSpecName : '2');
                 elseif (USEROPT <> ' ');
                   errMsg = 'Option ' + %trim(userOpt) + ' invalid.';
                   leave;
                 endif;
                 clear USEROPT;
                 update detail;
                readc(e)  detail;
              enddo;
              if (bConfirm);
                 if doConfirm();
                   bRefresh = *ON;
                 endif;
              endif;
              bConfirm = *OFF;
           endif;
         enddo;

         return;



             ///////////////////////////////////////////////////////
             // loadUDTF uses the QSYS2.SYSROUTINE View to list
             // the available routines.
             ///////////////////////////////////////////////////////
          dcl-proc loadUDTF;

             ///////////////////////////////////////////////////////
             //  SQL Indicators used to test for NULL returned
             //  for the designated column in the resultSet.
             ///////////////////////////////////////////////////////
           dcl-ds indy qualified inz;
             lib       int(5);       // Last SignOn
             type      int(5);       // Invalid SignOn Attempts
             name      int(5);       // Supplemental Group Profile Count
             specName  int(5);       // Supplemental Group Profiles
           end-Ds;

           dcl-s iName   int(5);
           dcl-s iSpec   int(5);
           dcl-s iLib    int(5);
           dcl-s fType  VARCHAR(16);
           dcl-s fLib   VARCHAR(16);
           dcl-s fFunc  VARCHAR(32);
           dcl-s fSpec  VARCHAR(128);
           dcl-s gLib   VARCHAR(128);
           dcl-s gFunc  VARCHAR(128);
           dcl-s gSpec  VARCHAR(128);
           dcl-s crtDate  Date;
           dcl-s iCrtDate int(5) inz(0);
           dcl-s rtnSQL char(5000);
           dcl-s i int(10);

             ///////////////////////////////////////////////////////
             // Just a standard Load Subfile setup
             ///////////////////////////////////////////////////////
           rrn = 0;
           csrpos = 1;   // Put Cursor on line 1 of subfile
           lineCount = 0;
           indds.funcSFL = *off;
           indds.funcSFLCTL = *off;
           write display;

           if (sFunc = '' and (sSchema = '' or %subst(sSchema:1:4) = '*ALL'));
             return;
           endIf;

           bldFuncList(sSchema : sFunc : sName : sType );

           clear detail;   // Clear Subfile record format fields.

             for i = 1 to 1000;
               fetchFuncList();
               IF (sqlState >= '02000'); // Nothing returned?
                 leave;
               endif;
               if (sType = 'P' and %SUBST(ds.fnType:1:1) <> 'P');
                 iter;
               elseif (sType = 'F' and %SUBST(ds.fnType:1:1) <> 'U');
                 iter;
               elseif (sType = 'V' and %SUBST(ds.fnType:1:1) <> 'V');
                 iter;
               endif;
               leave;
             endfor;

           IF (sqlState >= '02000'); // Nothing returned?
             errmsg = 'No Functions found for input parameters.';
             closeFuncList();
             return;   // return to caller/redisplay (on-exit should be called)
           endif;

           DOW (sqlState < '02000');
             fnSchema = ds.SPECLIB;
             fnSpecName = ds.SPECNAME;
             fnName = ds.RTNNAME;
             fnFunc = ds.RTNNAME;
             fnType = ds.FNTYPE;
             fnSQLType = ds.SQLOBJTYPE;
             fnCRTDATE = ds.CRTDATE;
             fnLang    = ds.LANG;
             fnParms   = ds.ParmCnt;
             fnSpec    = %trimR(fnSpecName) + ': ' + ds.EXTNAME;
             if (ds.PARMS <> '');
               fnSpec = %trimR(fnSpec) + '  PARMS(' + %trimR(ds.PARMS) + ')';
             endif;
             if (ds.DETERM = 'DET');
               fnSpec = %trimR(fnSpec) + ' DETERMINISTIC';
             endif;

             if (RRN < 5000);
               rrn += 1;
             else;
               sqlstate = '02000';
               leave;
             endif;
             indds.Func = *OFF;  // Shouldn't need these two "setoffs"
             indds.Proc = *OFF;  // But in the subfile it wasn't working 100%
             indds.Func = (fnType = 'UDTF' or fnType = 'UDF');
             indds.Proc = (fnType = 'PROC');
             write(e) detail;
             for i = 1 to 1000;
               fetchFuncList();
               IF (sqlState >= '02000'); // Nothing returned?
                 leave;
               endif;
               if (sType = 'P' and %SUBST(ds.fnType:1:1) <> 'P');
                 iter;
               elseif (sType = 'F' and %SUBST(ds.fnType:1:1) <> 'U');
                 iter;
               elseif (sType = 'V' and %SUBST(ds.fnType:1:1) <> 'V');
                 iter;
               endif;
               leave;
             endfor;
           enddo;

          // ON-EXIT;
            closeFuncList();
            lineCount = RRN;
          end-proc;



          dcl-proc addStmt;
            dcl-pi addStmt;
              cmdStmt varchar(640) const;
            end-pi;
            if (cmdStmt = '');
              return;
            endif;
            confirmRRN += 1;
            hCmdStg = %trimR(cmdStmt);
            cmdStg  = %trimR(cmdStmt);
            if (%len(cmdStmt) > %size(cmdStg));
              %subst(cmdStg: %size(cmdStg)-3) = '...';
            endif;
            OPT = '4';
            write punchList;
          end-proc;

          dcl-proc dropFn;
            dcl-pi dropFn;
               fType varchar(18) const;
               fLib  varchar(128) const;
               fName varchar(128) const;
            end-Pi;
            dcl-s dropStmt varchar(1024);

            dropStmt = 'DROP SPECIFIC ';

            if (fType = 'PROC');
              dropStmt += ' procedure ';
            else;
              dropStmt += ' function ';
            endIf;
            dropStmt += %trim(fLib) + '.' + %trim(fName);
            addStmt( dropStmt);
          end-Proc;

          dcl-proc doConfirm;
            dcl-pi doConfirm ind end-pi;
            dcl-s  rc ind inz(*OFF);
            dcl-s  restrictiveText varchar(32);
            dcl-s  restrictiveDrop char(1) inz('Y') static;
            dcl-s  logDrop         char(1) inz('Y') static;
            restrict = restrictiveDrop;
            logMsg   = logDrop;

            if (confirmRRN > 0);
              indds.confirmSFL = *on;
              indds.confirmCTL = *on;
              write confirmFN;
              exfmt CONFIRM;
              if (wsds.fKey = Enter);
                if (logMsg = 'N' or logMsg = ' ');
                  logDrop = 'N';
                else;
                  logDrop = 'Y';
                endif;
                if (restrict = 'N' or restrict = ' ');
                  restrictiveDrop = 'N';
                  clear restrictiveText;
                else;
                  restrictiveDrop = 'Y';
                  restrictiveText = ' RESTRICT ';
                endif;
                rc = *ON;
                readc(e) punchList;
                dow NOT (%eof() or %error());
                  if (opt <> ' ');

                    if (restrictiveText <> '');
                      hCmdStg = %trimR(hCmdStg) + restrictiveText;
                    endif;
                    if (logDrop = 'Y');
                      sndmsg( %trim(hCmdStg));
                    endif;
                    exec sql execute immediate rtrim(:hCmdStg);
                  endif;
                 readc(e) punchList;
                enddo;
              endif;
            endif;
            CONFIRMRRN = 0;
            indds.confirmSFL = *off;
            indds.confirmCTL = *off;
            write confirm;
            return rc;
          end-proc;

          dcl-proc rtvsrc;
           dcl-pi rtvsrc;
             fType varchar(18) const;
             fLib  varchar(128) const;
             fName varchar(128) const;
             fOpt  char(2) const options(*NOPASS);
           end-pi;

           dcl-s objtype varchar(32);
           dcl-s strseu  varchar(128)
            inz('STRSEU SRCFILE(QTEMP/IQ_TEMPSRC) SRCMBR(IQ_QRTVSRC) OPTION(');

           IF (%PARMS() >= %ParmNum(fOpt) and fOpt <> '');
              if (fOpt = '8');
                strseu = %TRIMR( strSEU ) + '2' + ')';
              else;
                strseu = %TRIMR( strSEU ) + fOpt + ')';
              endif;
           else;
              strseu = %TRIMR( strSEU ) + '5' + ')';
           endif;

            exec SQL VALUES upper(:fType) into :objType;

            if (%SUBST(objType:1:4) = 'PROC');
              objType = 'PROCEDURE';
            elseif (%SUBST(objType:1:4) = 'FUNC') or
                   (%SUBST(objType:1:4) = 'UDTF') or
                   (%SUBST(objType:1:3) = 'UDF');
              objType = 'FUNCTION';
            else;
              objType = %Trim(fType);
            endif;

            MONITOR;
              system('CRTSRCPF FILE(QTEMP/IQ_TEMPSRC) RCDLEN(92)');
            on-error;  // do nothing
            endmon;
            MONITOR;
              system('ADDPFM FILE(QTEMP/IQ_TEMPSRC) +
                               MBR(IQ_QRTVSRC) SRCTYPE(SQL)');
            on-error;  // do nothing
            endmon;
            MONITOR;
              system('CLRPFM FILE(QTEMP/IQ_TEMPSRC) +
                               MBR(IQ_QRTVSRC)');
            on-error;  // do nothing
            endmon;
            EXEC SQL call qsys2.generate_SQL(
                           CREATE_OR_REPLACE_OPTION => '1',
                           database_object_TYPE => :objType,
                           database_object_NAME => rTrim(:fName),
                           database_object_LIBRARY_NAME => rTrim(:fLib),
                           database_source_file_name => 'IQ_TEMPSRC',
                           database_source_file_library_name => 'QTEMP',
                           database_source_file_member => 'IQ_QRTVSRC',
                           replace_option => '1',
                           statement_formatting_option=>'0',
                           naming_option => 'SQL',
                           standards_option => '0',
                           header_option => '0',
                           system_name_option => '1'
                   );
           system(%trimR(strseu));
          end-proc;

          dcl-proc fetchFuncList;

            EXEC SQL FETCH FNL INTO
                 :ds.ORIGIN,   -- VARCHAR(10)  (Table func, column scalar, etc)
                 :ds.LANG,     -- VARCHAR(10)
                 :ds.PARMS:ds.iParms,    -- VARCHAR(16)
                 :ds.PARMCNT:ds.iParmCnt, --   int(5)
                 :ds.DETERM,   -- VARCHAR(16),
                 :ds.FNTYPE,   -- VARCHAR(5),
                 :ds.SQLOBJTYPE,  -- VARCHAR(18)
                 :ds.RTNLIB,   -- VARCHAR(128)
                 :ds.RTNNAME,  -- VARCHAR(128)
                 :ds.SPECLIB,   -- VARCHAR(128)
                 :ds.SPECNAME,  -- VARCHAR(128)
                 :ds.TEXT:ds.iText,        -- VARCHAR(50)
                 :ds.EXTNAME:ds.iExtName,     -- VARCHAR(279)
                 :ds.CRTDATE;

          end-proc;

          dcl-proc closeFuncList;
             EXEC SQL CLOSE FNL;
          end-proc;

          dcl-proc bldFuncList;
           dcl-pi bldFuncList;
             library varchar(128) const OPTIONS(*TRIM);
             routine varchar(128) const OPTIONS(*TRIM);
             nametype char(1) const OPTIONS(*NOPASS : *OMIT);
             rtnType  char(1) const OPTIONS(*NOPASS : *OMIT);
           end-pi;

           dcl-s lib_ID  varchar(128);
           dcl-s func_ID varchar(128);
           dcl-s name_TP char(1);
           dcl-s obj_TP  char(1);

           if (%Parms() >= %ParmNum(nameType));
             if (%addr(nameType) <> *NULL);
              name_TP = nameType;
             endif;
           endif;
           if (%Parms() >= %ParmNum(rtnType));
             if (%addr(rtnType) <> *NULL);
              obj_TP = rtnType;
             endif;
           endif;
           if (name_tp = '*');
              name_tp = ' ';
           endif;
           if (obj_tp = '*');
              obj_tp = ' ';
           endif;
           if (ROUTINE <> '');
              if (%scan('%' : ROUTINE) > 0 OR
                  %scan('*' : ROUTINE) > 0);
               func_ID = %ScanRPL('*':'%': ROUTINE);
              else;
               func_ID = %TRIM(ROUTINE) + '%';  // Always a generic lookup
              endif;
           endif;
           if (LIBRARY <> '');
              if (%scan('%' : LIBRARY) > 0 OR
                  %scan('*' : LIBRARY) > 0);
               lib_ID = %ScanRPL('*':'%': LIBRARY); // Generic when user-specified generic
              else;
               lib_ID = %TRIM(LIBRARY);
              endif;
           endif;

           EXEC SQL DECLARE FNL CURSOR FOR
            SELECT
               CASE ORIGIN
                    WHEN 'B' THEN 'BUILTIN'
                    WHEN 'E' THEN CASE FUNCTION_TYPE
                                         WHEN 'T' THEN 'TABLE'
                                         WHEN 'C' THEN 'COLUMN'
                                         WHEN 'S' THEN 'SCALAR'
                                  END
                    WHEN 'U' THEN 'SOURCED'
                    WHEN 'S' THEN 'SYSTEM'
                    ELSE ORIGIN
               END,
               COALESCE(EXTERNAL_LANGUAGE,'SQL/PL') as LANG,
                 CASE
                   WHEN in_parms > 0 THEN
                       CASE FUNCTION_TYPE
                         WHEN ' ' THEN 'I:'
                         ELSE ''
                       END CONCAT in_parms
                   ELSE ''
                 END CONCAT
                 CASE
                   WHEN out_parms > 0 THEN
                       CASE
                         WHEN IN_PARMS > 0 THEN ','
                         ELSE ''
                       END CONCAT
                         CASE FUNCTION_TYPE
                           WHEN ' ' THEN 'O:'
                           ELSE ''
                         END CONCAT out_parms
                   ELSE ''
                 END CONCAT
                 CASE
                   WHEN inout_parms > 0 THEN
                       CASE
                         WHEN IN_PARMS > 0
                           OR OUT_PARMS > 0 THEN ','
                         ELSE ''
                       END CONCAT
                         CASE FUNCTION_TYPE
                           WHEN ' ' THEN 'IO:'
                           ELSE ''
                         END CONCAT inout_parms
                   ELSE ''
               END AS PARAMETERS,
               cast((in_parms + out_parms + inout_parms) as smallint) as parms,
               CASE IS_DETERMINISTIC
               WHEN 'YES' THEN 'DET'
               ELSE CASE WHEN FUNCTION_TYPE in ('S','T','C') THEN 'NOT'
                    ELSE ''
                    END
               END AS CALL_TYPE,
               CASE FUNCTION_TYPE
                WHEN 'S' THEN 'UDF'   -- Scalar Fn
                WHEN 'T' THEN 'UDTF'  -- Table Fn
                WHEN 'C' THEN 'COLUMN' -- Column Fn
                WHEN 'P' THEN 'PROC'  -- Procedure
                ELSE CASE WHEN LEFT(ROUTINE_TYPE, 4) = 'PROC'
                          THEN 'PROC'
                          ELSE LEFT(ROUTINE_TYPE,5) END
               END AS FTYPE,
               CAST(LEFT(ROUTINE_TYPE, 9) AS VARCHAR(18)) AS SQLOBJTYPE,

               ROUTINE_SCHEMA,
               ROUTINE_NAME,    -- Function Name
               SPECIFIC_SCHEMA,
               SPECIFIC_NAME,   -- Specific Name
               CAST(ROUTINE_TEXT AS VARCHAR(50)) AS TEXT,
               EXTERNAL_NAME as EXTNAME,
               cast(VARCHAR_FORMAT(CAST(ROUTINE_CREATED as DATE),:dateFmtEx)
                         as VARCHAR(10)) as CRTDATE

          FROM qsys2.sysroutines
          WHERE (
                 ((:NAME_TP = ' ' or :NAME_TP = 'N') and
                 ROUTINE_NAME LIKE CASE WHEN :FUNC_ID  = '' THEN ROUTINE_NAME
                                        ELSE :FUNC_ID END)
               OR
                 ((:NAME_TP = ' ' or :NAME_TP = 'S') and
                 SPECIFIC_NAME LIKE CASE WHEN :FUNC_ID = '' THEN SPECIFIC_NAME
                                         ELSE :FUNC_ID END)
                )
               AND
                (
                 ((:NAME_TP = ' ' or :NAME_TP = 'N') and
                  ROUTINE_SCHEMA = CASE WHEN :LIB_ID = ''
                                       THEN ROUTINE_SCHEMA
                                       ELSE :LIB_ID END)
               OR
                 ((:NAME_TP = ' ' or :NAME_TP = 'S') and
                SPECIFIC_SCHEMA = CASE WHEN :LIB_ID = ''
                                       THEN SPECIFIC_SCHEMA
                                       ELSE :LIB_ID END)
                )

            UNION
             -- Added OBJECT_STATISTICS so that Sequences, Indexes, etc. are
             -- also included. Only SQL_OBJECT_TYPE <> NULL are retrieved.
            SELECT 'OBJ' AS ORIGIN,
                   'N/A' AS LANG,
                   CAST(NULL AS VARCHAR(10)) AS PARMS,
                   CAST(NULL AS SMALLINT) AS PARMCount,
                   CAST('' AS VARCHAR(10)) AS DETERM,
                   OL.SQL_OBJECT_TYPE as FnType,
                   OL.SQL_OBJECT_TYPE as SQLOBJTYPE,
                   OL.OBJLONGSCHEMA   as ROUTINE_SCHEMA,
                   OL.OBJLONGNAME     as ROUTINE_NAME,
                   LN.OBJNAME         as SPECIFIC_SCHEMA,
                   OL.OBJNAME         as SPECIFIC_NAME,
                   OL.OBJTEXT AS TEXT,
                   CAST('' AS VARCHAR(10)) AS EXTNAME,
                   CAST(
                     VARCHAR_FORMAT(CAST(OL.OBJCREATED AS DATE), :dateFmtEx)
                      as VARCHAR(10)) AS CRTDATE
              FROM table(object_statistics(:LIB_ID, '*ALL')) OL
                  ,LATERAL (select objname
                        from table(object_statistics('QSYS','*LIB',
                                                      OL.OBJLONGSCHEMA)) LIB) LN
             WHERE OL.SQL_OBJECT_TYPE is NOT NULL and
                   OL.SQL_OBJECT_TYPE NOT IN ('FUNCTION','PROCEDURE','VIEW')
                   and
             (
                  ((:NAME_TP = ' ' or :NAME_TP = 'N') and
                   OL.OBJNAME LIKE CASE WHEN :FUNC_ID = '' THEN OL.objname
                                        ELSE :FUNC_ID END)
               OR
                 ((:NAME_TP = ' ' or :NAME_TP = 'S') and
                 OL.OBJLONGNAME LIKE CASE WHEN :FUNC_ID = ''
                                         THEN OL.OBJLONGNAME
                                         ELSE :FUNC_ID END)
                )

            UNION
            SELECT 'VIEW' AS ORIGIN,
                   'SQL/PL' AS LANG,
                   CAST(NULL AS VARCHAR(10)) AS PARMS,
                   CAST(NULL AS SMALLINT) AS PARMCount,
                   CAST('' AS VARCHAR(10)) AS DETERM,
                   'VIEW' AS FNTYPE,
                   'VIEW' AS SQLOBJTYPE,
                -- Modified correlational names to match SYSROUTINES
                   TABLE_SCHEMA AS ROUTINE_SCHEMA,
                   TABLE_NAME AS ROUTINE_NAME,
                   SYSTEM_VIEW_SCHEMA AS SPECIFIC_SCHEMA,
                   SYSTEM_VIEW_NAME AS SPECIFIC_NAME,
                   VD.OBJTEXT AS TEXT,
                   CAST('' AS VARCHAR(10)) AS EXTNAME,
                   CAST(
                     VARCHAR_FORMAT(CAST(VD.OBJCREATED AS DATE), :dateFmtEx)
                      as VARCHAR(10)) AS CRTDATE
              FROM qsys2.sysviews V,
                   LATERAL (
                     SELECT *
                       FROM TABLE (
                           qsys2.object_statistics(
                             V.SYSTEM_VIEW_SCHEMA, '*FILE',
                             V.SYSTEM_VIEW_NAME)) OD
                         WHERE OD.SQL_OBJECT_TYPE is NOT NULL
                  ) VD
          WHERE (
                 ((:NAME_TP = ' ' or :NAME_TP = 'N') and
                 v.TABLE_NAME LIKE CASE WHEN :FUNC_ID  = '' THEN v.TABLE_NAME
                                        ELSE :FUNC_ID END)
               OR
                 ((:NAME_TP = ' ' or :NAME_TP = 'S') and
                 V.SYSTEM_VIEW_NAME LIKE CASE WHEN :FUNC_ID = ''
                                         THEN v.SYSTEM_VIEW_NAME
                                         ELSE :FUNC_ID END)
                )
               AND
                (
                 ((:NAME_TP = ' ' or :NAME_TP = 'N') and
                  V.TABLE_SCHEMA = CASE WHEN :LIB_ID = ''
                                       THEN V.TABLE_SCHEMA
                                       ELSE :LIB_ID END)
               OR
                 ((:NAME_TP = ' ' or :NAME_TP = 'S') and
                v.SYSTEM_VIEW_SCHEMA = CASE WHEN :LIB_ID = ''
                                       THEN V.SYSTEM_VIEW_SCHEMA
                                       ELSE :LIB_ID END)
                )

          ORDER BY ROUTINE_SCHEMA,ROUTINE_NAME;

           EXEC SQL OPEN FNL;

          end-proc;

             // QUSRJOBI (Retrieve Job Attributes) API call
             // Purpose: Currently need the Job's DATFMT and DATDEP
             // Used with the SQL VARCHAR_FORMAT function to
             // convert the creation date to the format of the job,
             // but includes a 4-digit year instead of just 2-digits.
             // TO DO that: varchar_format( date_value, date_format);
             // e.g., varchar_format( routine_created, :dateFmtEx);
             // where DATEFMTEX contains 'MM/DD/YYYY' or your
             // job's extended date format code.
          dcl-proc getJobInfo ;
           dcl-pi  getJobInfo char(10);
             jobInfo likeDS(QUSI0400_t) OPTIONS(*NOPASS);
           end-pi;
              // Get Job's DATFMT in expanded format
              // That is, MDY is returned as MM/DD/YYYY
              // while DMY is returned as DD.MM.YYYY
              // The job's date Sep is used to edit the format.
              // Use with SQL VARCHAR_FORMAT to convert dates
           dcl-s job char(26) inz('*');
           dcl-s intJob char(16) inz;
           dcl-ds jobDesc likeDS(QUSI0400_t) Inz;
           dcl-ds ec likeDS(QUSEC_T) Inz;
           dcl-s dateFmt varchar(5);
           dcl-s dateFmt2 varchar(10);
           dcl-s dateSep char(1);

           clear ec;
           ec.bytes_Provided = %size(ec);
           clear jobDesc;
           QusrJobAttr( jobDesc : %size(jobDesc) : 'JOBI0400' :
                        job : intJob : ec);
           dateSep = jobDesc.Date_Sep;
           dateFmt = %SUBST(jobDesc.Date_Format:2:3);
           dateFmt2= %SUBST(dateFmt:1:1) + %SUBST(dateFmt:1:1) + dateSep +
                     %SUBST(dateFmt:2:1) + %SUBST(dateFmt:2:1) + dateSep +
                     %SUBST(dateFmt:3:1) + %SUBST(dateFmt:3:1);
           dateFmt2= %SCANRPL('YY' : 'YYYY' : dateFmt2);
            if (%PARMS() >= %ParmNum(JobInfo));
              jobInfo = JobDesc;
            endif;
            return dateFmt2;
           end-proc;
