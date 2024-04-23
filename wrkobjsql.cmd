 WRKOBJSQL:  CMD        PROMPT('Work with SQL Objects')
             PARM       KWD(LIB) TYPE(*NAME) LEN(10) DFT(*CURLIB) +
                          SPCVAL((*NONE ' ') (*CURLIB *CURLIB)) EXPR(*YES) +
                          PROMPT('Schema')
             PARM       KWD(FN) TYPE(*NAME) LEN(32) DFT(*ALL) +
                          SPCVAL((*ALL ' ')) EXPR(*YES) +
                          PROMPT('Function or procedure name') 
