# WRKOBJSQL
Work with SQL Objects for IBM i
<p>The WRKOBJSQL command allows you to view a list of SQL-related objects for the specified library. 
You may do things like retrieve the SQL source code that was used to create the SQL object, view that source code, delete (drop) the object and more.</p>
<p>This version supports all SQL types. Previously it supported UDTF, UDF, PROC, and some VIEWs. Now all SQL types are visible to the users.</p>
<h3>Compiling instructions</h3>
<p>After uploading the source code to your IBM i source file members, use the following CL commands to create this utility.</p>
<p>Step 1: Create the Command Definition Object</p>
<pre>CRTCMD CMD(COZTOOLS/WRKOBJSQL) PGM(COZTOOLS/WRKOBJSQL) SRCFILE(COZTOOLS/QCMDSRC) SRCMBR(WRKOBJSQL) REPLACE(*YES) </pre>
<p>Step 2: Create the Display File used by the RPG IV program</p>
<pre>CRTDSPF FILE(COZTOOLS/WRKOBJSQL) SRCFILE(COZTOOLS/QDDSSRC) SRCMBR(WRKOBJSQL) REPLACE(*YES)</pre>
<p>Step 3: Lastly, compile the SQL RPG IV source member</p>
<pre>CRTSQLRPGI OBJ(COZTOOLS/WRKOBJSQL) SRCFILE(COZTOOLS/QRPGLESRC) SRCMBR(WRKOBJSQL) OBJTYPE(*PGM) REPLACE(*YES)</pre>
<h3>Using WRKOBJSQL</h3>
<p>After compiling the command and related objects, use the WRKOBJSQL CL command to work with SQL objects in any library.</p>
<pre>WRKOBJSQL SQLTOOLS</pre>
<p>In this example, the SQL Tools product library is used. You should explore the QSYS2 library as well.</p>
