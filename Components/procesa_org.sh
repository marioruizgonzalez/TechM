#!/bin/bash
# -*- encoding: utf-8 -*-
#procesa_org

validaORA(){
if [ "$1" = "AVS" ]; then
if [ `grep "ORA-" $current_log | wc -l` -gt 0 ]; then
v_exit_CC='FALSE'
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Tienda ' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ERROR | Por favor verifique con su administrador' $v_exit_CC >> $current_log
fi
elif [ "$1" = "NEXT" ]; then 
if [ `grep "ORA-" $current_log | wc -l` -gt 0 ]; then
v_exit_DF='FALSE'
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Tienda ' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | ERROR | Por favor verifique con su administrador' $v_exit_DF >> $current_log
fi
fi
}

if [ "$1" = "AVS" ]; then
#conexion a base de datos ASD y ASM
. /opt/apps/batch/Asd_transactions/cfg/asd_conexion.sh
. /opt/apps/batch/Asd_transactions/cfg/asm_conexion.sh
source /etc/profile

#Rutas
rutaout=/opt/apps/batch/Asd_transactions/out/
rutacfg=/opt/apps/batch/Asd_transactions/cfg/
rutabin=/opt/apps/batch/Asd_transactions/bin/

current_log="$3"

temporal=/opt/apps/batch/Asd_transactions/out/temporal.txt


iniciaASD  () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | INICIA GENERACION DE ARCHIVOS CASH AND CARRY' >> $current_log
Subinventory=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT pos.pos_id||'_'||pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (1)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
SubinventoryACC=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT pos.pos_id||'_'||pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (2)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
SubinventoryDWS=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT pos.pos_id||'_'||pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (3)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
SubinventorySR=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (4,5,6,7)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
if [ -z $Subinventory ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | No existe subinventario para la tienda: ' $org_id >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Se procesa tienda con subinventario: ' $Subinventory >> $current_log
insertaAFG_RS
insertaAFG_SR
fi
}
insertaAFG_RS () {
StorCode=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT distinct pos.org_subinventory ||'|'|| pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (1)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
Stor=$(echo "$StorCode" | tr -d '[[:space:]]')
temp=$(echo "$temporal" | tr -d '[[:space:]]')
regularSale=$(sqlplus -S $asdconexion  << EOF
   set serveroutput on size 1000000; 
   set trimspool ON;
   SET SQLBLANKLINES ON;
   SET HEAD OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
	spool "$temp"
   
DECLARE   

resultado SYS_REFCURSOR;
registro  varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_RS','$Stor','$org_id','',resultado);

	loop
		fetch resultado into registro;
		exit when resultado%notfound;
		if trim(registro) = 'HDR|0|ASD|CC' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;
	end loop;

END;
/

	spool off;
EOF
)
validaORA
if [[ ! -z $regularSale ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Registros encontrados ... ' >> $current_log
creaarchivoGL
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | No se encontraron registros ... ' >> $current_log
rm -f $temp
fi
insertaAFG_ACC
}
insertaAFG_ACC () {
if [ -z $SubinventoryACC ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | No existe subinventario para la tienda: ' $org_id >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Se procesa tienda con subinventario: ' $SubinventoryACC >> $current_log
StorCodeACC=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT  pos.org_subinventory ||'|'||pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (2)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
StorACCR=$(echo "$StorCodeACC" | tr -d '[[:space:]]')
temp=$(echo "$temporal" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Obtiene StorCode para registros' $StorACCR >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Buscando registros para la tienda' $org_id >> $current_log
###
subACCR=$(echo "$StorACCR" | tr '\n' ",")
subACCA=$(echo "$SubinventoryACC" | tr '\n' ",")
inicioACCR=0
longACCR=$((${#subACCR}-2))
subACCR=${subACCR:${inicioACCR}:${longACCR}}
#
inicioACCA=1
longACCA=$((${#subACCA}-2))
subACCA=${subACCA:${inicioACCA}:${longACCA}}
#
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Subinventarios: '$subACCR >> $current_log
OIFS=$IFS;
IFS='\,';
accRSubArray=($subACCR);
accASubArray=($subACCA);
j=0;
while [ $j -lt ${#accRSubArray[@]} ]
do
subinvenACCR=`echo "${accRSubArray[$j]}";`
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Store Code ACC : '$subinvenACCR >> $current_log
subinvenACCA=`echo "${accASubArray[$j]}";`
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Subinventario del archivo : '$subinvenACCA >> $current_log
j=$[$j+1]
##########
accesorios=$(sqlplus -S $asdconexion  << EOF
   set serveroutput on size 1000000; 
   set trimspool ON;
   SET SQLBLANKLINES ON;
   SET HEAD OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
	spool "$temp"
   
DECLARE   

resultado SYS_REFCURSOR;
registro    varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_ACC','$subinvenACCR','$org_id','',resultado); 

	loop
		fetch resultado into registro;
		exit when resultado%notfound;	
		if trim(registro) = 'HDR|0|ASD|CC' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;		
	end loop;

END;
/
	spool off;
EOF
)
validaORA
if [[ ! -z $accesorios ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Registros encontrados ... ' >> $current_log
creaarchivoGL_ACC
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | No se encontraron registros ...' >> $current_log
rm -f $temp
fi
done
IFS=$OIFS;
fi
insertaAFG_DWS
}
insertaAFG_DWS () {
if [ -z $SubinventoryDWS ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | No existe subinventario para la tienda: ' $org_id >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Se procesa tienda con subinventario: ' $SubinventoryDWS >> $current_log
StorCodeDWS=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT pos.org_subinventory ||'|'|| pos.subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (3)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
StorDWSR=$(echo "$StorCodeDWS" | tr -d '[[:space:]]')
temp=$(echo "$temporal" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Obtiene StorCode para registros' $StorDWSR >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Buscando registros para la tienda' $org_id >> $current_log
###
subDWSR=$(echo "$StorDWSR" | tr '\n' ",")
subDWSA=$(echo "$SubinventoryDWS" | tr '\n' ",")
inicioDWSR=1
longDWSR=$((${#subDWSR}-2))
subDWSR=${subDWSR:${inicioDWSR}:${longDWSR}}
#
inicioDWSA=1
longDWSA=$((${#subDWSA}-2))
subDWSA=${subDWSA:${inicioDWSA}:${longDWSA}}
#
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Subinventarios: '$subDWSR >> $current_log
OIFS=$IFS;
IFS='\,';
dwsRSubArray=($subDWSR);
dwsASubArray=($subDWSA);
j=0;
while [ $j -lt ${#dwsRSubArray[@]} ]
do
subinvenDWSR=`echo "${dwsRSubArray[$j]}";`
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Store Code DWS : '$subinvenDWSR >> $current_log
subinvenDWSA=`echo "${dwsASubArray[$j]}";`
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Subinventario del archivo : '$subinvenDWSA >> $current_log
j=$[$j+1]
##########
eq_sin_serv=$(sqlplus -S $asdconexion  << EOF
   set serveroutput on size 1000000; 
   set trimspool ON;
   SET SQLBLANKLINES ON;
   SET HEAD OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
	spool "$temp"
   
DECLARE   

resultado SYS_REFCURSOR;
registro    varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_DWS','$subinvenDWS','$org_id','',resultado); 

	loop
		fetch resultado into registro;
		exit when resultado%notfound;	
		if trim(registro) = 'HDR|0|ASD|CC' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;		
	end loop;

END;
/
	spool off;
EOF
)

if [[ ! -z $eq_sin_serv ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Registros encontrados ... ' >> $current_log
creaarchivoGL_DWS
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | No se encontraron registros ...' >> $current_log
rm -f $temp
fi
done
IFS=$OIFS;
fi
}
insertaAFG_SR () {
if [ -z $SubinventorySR ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | SAR | No existe subinventario para la tienda: ' $org_id >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | SAR | Se procesa tienda con subinventario: ' $SubinventorySR >> $current_log
StoreCodeSR=$(sqlplus -S $asmconexion << EOF
set heading off;
set feedback off;
SELECT DISTINCT pos.org_subinventory
FROM  asmdb.asm_pos_inventory  pos 
    , asmdb.asm_cat_inventory  cat 
WHERE pos.inventory_id = cat.inventory_id
  AND pos.inventory_id in (4,5,6,7)
  AND pos.inv_ownership = 0
  AND pos.pos_id = $org_id;
EOF
)
StorSR=$(echo "$StoreCodeSR" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | SAR | StorCode para registros ' $StorSR >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | SAR | Buscando registros para la tienda' $org_id >> $current_log
subinventories=$(echo "$SubinventorySR" | tr '\n' "\,")
subinventories=$(echo "$subinventories" | sed -e "s/\,/\'\,\'/g")
inicio=2
long=$((${#subinventories}-4))
subinventories=${subinventories:${inicio}:${long}}
#####
#org_sub=$(echo "$org_id" | sed -e "s/.*/\'\'&\'\'/")
#####
OIFS=$IFS;
IFS='\,';
subinventoriesArray=($subinventories);
for ((i=0; i<${#subinventoriesArray[@]}; ++i));
do
subinven=`echo "${subinventoriesArray[$i]}";`
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Subinventario del archivo : ' $subinven >> $current_log
##########
serviceRepair=$(sqlplus -S $asdconexion  << EOF
   set serveroutput on size 1000000; 
   set trimspool ON;
   SET SQLBLANKLINES ON;
   SET HEAD OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
	spool "$temp"
   
DECLARE   

resultado SYS_REFCURSOR;
registro    varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_SAR','$StorSR','$org_id',$subinven,resultado); 

	loop
		fetch resultado into registro;
		exit when resultado%notfound;	
		if trim(registro) = 'HDR|0|ASD|CC' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;		
	end loop;

END;
/
	spool off;
EOF
)
validaORA
if [[ ! -z $serviceRepair ]]; then
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Registros encontrados ... ' >> $current_log
creaarchivoGL_SR
else 
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | No se encontraron registros ...' >> $current_log
rm -f $temp
fi
done
IFS=$OIFS;
fi
actualizaAFG
}
creaarchivoGL () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Inserta proceso AFG' >> $current_log
SubinventoryCode=$(echo "$Subinventory" | tr -d '[[:space:]]')
opus_file=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_subinventories1   ASD.ASD_TRANSACTIONS_FILES_TYP;
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

v_subinventories1:=ASD.ASD_TRANSACTIONS_FILES_TYP('$SubinventoryCode');
v_files:=ASD.IN_FILES(v_subinventories1);

asd.asd_transactions_pkg.inicio_prc('CC GL','AFG','P','GL',1,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 
    
END;
/

EOF
)
validaORA
if [ -z $opus_file ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Error no se inserta correctamente proceso AFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Se inserto correctamente proceso AFG' >> $current_log
opus_file=$(echo "$opus_file" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Obtiene nombre del archivo para GL : ' $opus_file >> $current_log
archivoGL=$(echo "$rutaout$opus_file" | tr -d '[[:space:]]')
archivoGL=$(echo "$archivoGL" | tr -d '\n')
#echo $regularSale >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Se crea archivo: ' $archivoGL >> $current_log
grep . $temp > $archivoGL
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | RS | Se creo correctamente el archivo: ' $archivoGL >> $current_log
fi
}
creaarchivoGL_ACC(){
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Inserta proceso AFG' >> $current_log
opus_fileACC=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_subinventories1   ASD.ASD_TRANSACTIONS_FILES_TYP;
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

v_subinventories1:=ASD.ASD_TRANSACTIONS_FILES_TYP('$subinvenACCA');
v_files:=ASD.IN_FILES(v_subinventories1);

asd.asd_transactions_pkg.inicio_prc('CC GL','AFG','P','GL',2,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 
    
END;
/

EOF
)
validaORA
if [ -z $opus_fileACC ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Error no se inserta correctamente proceso AFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Se inserto correctamente proceso AFG' >> $current_log
opus_fileACC=$(echo "$opus_fileACC" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Obtiene nombre del archivo para GL ' $opus_fileACC >> $current_log
archivoGLacc=$(echo "$rutaout$opus_fileACC" | tr -d '[[:space:]]')
archivoGLacc=$(echo "$archivoGLacc" | tr -d '\n')
#echo $accesorios >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Se crea archivo: ' $archivoGLacc >> $current_log
grep . $temp > $archivoGLacc
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | ACC | Se creo el archivo correctamente: ' $opus_fileACC >> $current_log
fi
}
creaarchivoGL_DWS(){
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Inserta proceso AFG' >> $current_log
subinvenDWSA=$(echo "$subinvenDWSA" | tr -d '[[:space:]]')
opus_fileDWS=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_subinventories1   ASD.ASD_TRANSACTIONS_FILES_TYP;
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

v_subinventories1:=ASD.ASD_TRANSACTIONS_FILES_TYP('$subinvenDWSA');
v_files:=ASD.IN_FILES(v_subinventories1);

asd.asd_transactions_pkg.inicio_prc('CC GL','AFG','P','GL',3,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 
    
END;
/

EOF
)
validaORA
if [ -z $opus_fileDWS ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Error no se inserta correctamente proceso AFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Se inserto correctamente proceso AFG' >> $current_log
opus_fileDWS=$(echo "$opus_fileDWS" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Obtiene nombre del archivo para GL ' $opus_fileDWS >> $current_log
archivoGLdws=$(echo "$rutaout$opus_fileDWS" | tr -d '[[:space:]]')
archivoGLdws=$(echo "$archivoGLdws" | tr -d '\n')
#echo $eq_sin_serv >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Se crea archivo: ' $archivoGLdws >> $current_log
grep . $temp > $archivoGLdws
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | DWS | Se creo el archivo correctamente: ' $opus_fileDWS >> $current_log
fi
}
creaarchivoGL_SR () {
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Inserta proceso AFG' >> $current_log
subinven=$(echo "$subinven" | tr -d '[[:space:]]')
opus_fileSR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_subinventories1   ASD.ASD_TRANSACTIONS_FILES_TYP;
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

v_subinventories1:=ASD.ASD_TRANSACTIONS_FILES_TYP($subinven);
v_files:=ASD.IN_FILES(v_subinventories1);

asd.asd_transactions_pkg.inicio_prc('CC GL','AFG','P','GL',4,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 
    
END;
/

EOF
)
validaORA
if [ -z $opus_fileSR ]; then
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Error no se inserta correctamente proceso AFG' >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Se inserto correctamente proceso AFG' >> $current_log
opus_fileSR=$(echo "$opus_fileSR" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Obtiene nombre del archivo para GL ' $opus_fileSR >> $current_log
archivoGLsr=$(echo "$rutaout$opus_fileSR" | tr -d '[[:space:]]')
archivoGLsr=$(echo "$archivoGLsr" | tr -d '\n')
#echo $serviceRepair >> $current_log
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Se crea archivo: ' $archivoGLsr >> $current_log
grep . $temp > $archivoGLsr
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")`'GL | CC | '$org_id' | SAR | Se creo el archivo correctamente: ' $opus_fileSR >> $current_log
fi
}
actualizaAFG () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualiza proceso AFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Proceso AFG' >> $current_log
update_AFG=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','AFG','P','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_AFG ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error no se actualizo correctamente proceso AFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Se actualizo correctamente proceso AFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Fin proceso AFG' >> $current_log
insertaAUR
fi
}
insertaAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inicia proceso AUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Proceso AUR' >> $current_log
insert_AUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','AUR','P','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 



END;
/

EOF
)
validaORA
if [ -z $insert_AUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error al insertar proceso AUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inserto correctamente proceso AUR' >> $current_log
procesaAUR
fi
}
procesaAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualiza registros procesados AUR' >> $current_log
process_AUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('RECORDED CC','AUR','','GL_CC',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).code);
END LOOP; 

END;
/

EOF
)
validaORA
if [ $process_AUR  != 10 ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error al actualiza registros procesados AUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualizo correctamente los registros procesados AUR' >> $current_log
actualizaAUR
fi
}
actualizaAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualiza proceso AUR' >> $current_log
update_AUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','AUR','T','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_AUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error no se inserta correctamente proceso AUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Se actualizo correctamente proceso AUR' >> $current_log
insertaAFTP
fi
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Fin proceso AUR' >> $current_log

}
insertaAFTP() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inicia proceso AFTP' >> $current_log
insert_AFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','AFTP','P','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_AFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error al insertar proceso AFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inserto correctamente proceso AFTP' >> $current_log
enviaftp
fi

}
enviaftp () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Preparando envio de archivos GL por SFTP' >> $current_log
cd $rutacfg
sftpCC='ERROR-SFTP'
for fileAFTP in "$insert_AFTP"
do
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Parametro para SFTP...' $fileAFTP >> $current_log
./sftpGL.sh $fileAFTP >> $current_log
if [ $? -eq 0 ]; then
sftpCC='SUCCESS-SFTP'
else
sftpCC='ERROR-SFTP'
fi
done
if [ $sftpCC = 'SUCCESS-SFTP' ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Envio por SFTP fue exitoso' >> $current_log
cd $rutabin
actualizaAFTP
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error el envio por SFTP no fue exitoso' >> $current_log
fi
}
actualizaAFTP () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualiza proceso AFTP' >> $current_log
update_AFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','AFTP','T','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_AFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error no se inserta correctamente proceso AFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Se actualizo correctamente proceso AFTP' >> $current_log
insertaADEL
fi
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Fin proceso AFTP' >> $current_log
}
insertaADEL() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inicia proceso ADEL' >> $current_log
insert_ADEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','ADEL','P','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_ADEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error al insertar proceso ADEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Inserto correctamente proceso ADEL' >> $current_log
procesaADEL
fi
}
procesaADEL() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Elimina archivos del File System ADEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Elimina archivos' >> $current_log
fileadel=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

CURSOR c_count_adel is
SELECT COUNT(file_name)
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'AFTP'
AND organization = $org_id
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

CURSOR c_adel is
SELECT file_name
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'AFTP'
AND organization = $org_id
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

v_cout_adel     VARCHAR2(50):=NULL;
v_file          VARCHAR2(250):=NULL;

BEGIN

OPEN c_count_adel;
FETCH c_count_adel INTO v_cout_adel;
IF v_cout_adel <> '0' THEN
    OPEN c_adel;
    LOOP FETCH c_adel INTO v_file;
    EXIT WHEN c_adel%notfound;
        dbms_output.put_line( v_file );
    END LOOP;
    CLOSE c_adel;
ELSE
    dbms_output.put_line( 'N-ADEL' );
END IF;    
CLOSE c_count_adel;

END;
/

EOF
)
validaORA
if [ "$fileadel" != "N-ADEL" ]; then
let rec=0
echo "${fileadel}" | while read line
do
archivoDelete=$(echo "$rutaout$line" | tr -d '[[:space:]]')
if [ -f $archivoDelete ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Se elimina el archivo: ' $archivoDelete >> $current_log
rm -f $archivoDelete
let rec=rec+1;
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | No se encontró el archivo, revisar con su administrador del sistema' >> $current_log
fi
done
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | No hay archivos a eliminar' >> $current_log
fi
actualizaADEL
}
actualizaADEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Actualiza proceso ADEL' >> $current_log
update_ADEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','ADEL','T','GL',0,v_files,'$org_id',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_ADEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Error no se inserta correctamente proceso ADEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Se actualizo correctamente proceso ADEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Fin proceso ADEL' >> $current_log
fi
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | TERMINA PROCESO PARA GENERAR ARCHIVO QUE SERA ENVIADO A GL' >> $current_log
}
##################################################
insertaCFG  () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Buscando registros de la tienda  ' $org_id >> $current_log
temp=$(echo "$temporal" | tr -d '[[:space:]]')
cesatCC=$(sqlplus -S $asdconexion << EOF
   set serveroutput on size 1000000; 
   set trimspool on;
   SET SQLBLANKLINES ON;
   SET HEAD  OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
   spool "$temp"
   
DECLARE   

resultado SYS_REFCURSOR;
registro    varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_CESAT_CC','','','',resultado);   

	loop
		fetch resultado into registro;
		exit when resultado%notfound;
		if trim(registro) = 'HDR|0|ASD|CC' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;
	end loop;

END;
/
   
   spool off;
EOF
)
if [[ ! -z $cesatCC ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Registros encontrados ... ' >> $current_log
creaarchivoCESATCC
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | No se encontraron registros ... ' >> $current_log
rm -f $temp
fi
actualizaCFG
}
creaarchivoCESATCC () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserta proceso CFG' >> $current_log
cesat_file=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('CC CESAT','CFG','P','CESAT',1,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $cesat_file ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error no se inserta correctamente proceso CFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se inserto correctamente proceso CFG' >> $current_log
cesat_file=$(echo "$cesat_file" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Obtiene nombre del archivo para CESAT' >> $current_log
archivoCESAT=$(echo "$rutaout$cesat_file" | tr -d '[[:space:]]')
archivoCESAT=$(echo "$archivoCESAT" | tr -d '\n')
#echo $cesatCC >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se crea archivo: '$cesat_file >> $current_log
grep . $temp > $archivoCESAT
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se creo el archivo correctamente: ' $archivoCESAT >> $current_log
fi
}
actualizaCFG () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualiza proceso CFG' >> $current_log
update_CFG=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','CFG','P','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_CFG ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error no se inserta correctamente proceso CFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se actualizo correctamente proceso CFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Fin proceso CFG' >> $current_log
insertaCUR
fi
}
insertaCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inicia proceso CUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserta proceso CUR' >> $current_log
insert_CUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','CUR','P','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_CUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error al insertar proceso CUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserto correctamente proceso CUR' >> $current_log
procesaCUR
fi
}
procesaCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualiza registros procesados AUR' >> $current_log
process_CUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('RECORDED CC','CUR','','CESAT_CC',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).code);
END LOOP; 

END;
/

EOF
)
validaORA
if [ $process_CUR != 10 ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error al actualiza registros procesados AUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualizo correctamente los registros procesados' >> $current_log
actualizaCUR
fi
}
actualizaCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualiza proceso CUR' >> $current_log
process_CUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','CUR','T','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $process_CUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error no se inserta correctamente proceso CUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se actualizo correctamente proceso CUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Fin proceso CUR' >> $current_log
insertaCFTP
fi
}
insertaCFTP() {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserta proceso CFTP' >> $current_log
insert_CFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','CFTP','P','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_CFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error al insertar proceso CFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserto correctamente proceso CFTP' >> $current_log
enviacftp
fi

}
enviacftp () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Envio de archivo CESAT por SFTP' >> $current_log
cd $rutacfg
cesat_file=$(echo "$cesat_file" | tr -d '[[:space:]]')
cesat_file=$(echo "$cesat_file" | tr -d '\n')
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Parametro para SFTP...' $cesat_file >> $current_log
./sftpCESAT.sh $cesat_file >> $current_log
if [ $? -eq 0 ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Envio por SFTP fue exitoso' >> $current_log
cd $rutabin
actualizaCFTP
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error el envio por SFTP no fue exitoso' >> $current_log
fi 
}
actualizaCFTP () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualiza proceso CFTP' >> $current_log
update_CFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','CFTP','T','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_CFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error no se inserta correctamente proceso CFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se actualizo correctamente proceso CFTP' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Fin proceso CFTP' >> $current_log
insertaCDEL
fi
}
insertaCDEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inicia proceso CDEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserta proceso CDEL' >> $current_log
insert_CDEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA CC','CDEL','P','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_CDEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error al insertar proceso CDEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Inserto correctamente proceso CDEL' >> $current_log
procesaCDEL
fi
}
procesaCDEL (){
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Elimina archivos del File System CDEL' >> $current_log
filecadelC=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

CURSOR c_count_adel is
SELECT COUNT(file_name)
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'CFTP'
AND organization = $org_id
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

CURSOR c_adel is
SELECT file_name
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'CFTP'
AND organization = $org_id
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

v_cout_adel     VARCHAR2(50):=NULL;
v_file          VARCHAR2(250):=NULL;

BEGIN

OPEN c_count_adel;
FETCH c_count_adel INTO v_cout_adel;
IF v_cout_adel <> '0' THEN
    OPEN c_adel;
    LOOP FETCH c_adel INTO v_file;
    EXIT WHEN c_adel%notfound;
        dbms_output.put_line( v_file );
    END LOOP;
    CLOSE c_adel;
ELSE
    dbms_output.put_line( 'N-CDEL' );
END IF;    
CLOSE c_count_adel;

END;
/

EOF
)
validaORA
if [ "$filecadelC" != "N-CDEL" ]; then
let recC=0
echo "${filecadelC}" | while read line
do
archivoDeleteC=$(echo "$rutaout$line" | tr -d '[[:space:]]')
if [ -f $archivoDeleteC ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se elimina el archivo: ' $archivoDeleteC >> $current_log
rm -f $archivoDeleteC
let recC=recC+1;
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | No se encontró el archivo, revisar con su administrador del sistema' >> $current_log
fi
done
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | No hay archivos a eliminar' >> $current_log
fi
actualizaCDEL
}
actualizaCDEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Actualiza proceso CDEL' >> $current_log
update_CDEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA CC','CDEL','T','CESAT',0,v_files,'$org_id',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_CDEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Error no se inserta correctamente proceso CDEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Se actualizo correctamente proceso CDEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Fin proceso CDEL' >> $current_log
fi
}
while IFS= read -r line
do
org_id=$(echo "$line" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Tienda ' >> $current_log
temporal=/opt/apps/batch/Asd_transactions/out/temporal"_$org_id".txt
checkProcessGLCC=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

v_asd_trx   asd.asd_acc_log%ROWTYPE;
v_process   NUMBER:=0;
c_adel      SYS_REFCURSOR;
c_aftp      SYS_REFCURSOR;
c_aur       SYS_REFCURSOR;
c_afg       SYS_REFCURSOR;

BEGIN

OPEN c_adel FOR
    SELECT *
    FROM asd.asd_acc_log
    WHERE organization = '$org_id'
    AND process = 'ADEL'
    AND init_date between to_date(trunc(sysdate-1) || 
    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    ORDER BY ID;
    FETCH c_adel INTO v_asd_trx;
    IF (c_adel%NOTFOUND) THEN
        OPEN c_aftp FOR
            SELECT *
            FROM asd.asd_acc_log
            WHERE organization = '$org_id'
            AND process = 'AFTP'
            AND init_date between to_date(trunc(sysdate-1) || 
            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
            ORDER BY ID;
            FETCH c_aftp INTO v_asd_trx;
            IF (c_aftp%NOTFOUND) THEN
                OPEN c_aur FOR
                    SELECT *
                    FROM asd.asd_acc_log
                    WHERE organization = '$org_id'
                    AND process = 'AUR'
                    AND init_date between to_date(trunc(sysdate-1) || 
                    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                    ORDER BY ID;
                    FETCH c_aur INTO v_asd_trx;
                    IF (c_aur%NOTFOUND) THEN
                        OPEN c_afg FOR
                            SELECT *
                            FROM asd.asd_acc_log
                            WHERE organization = '$org_id'
                            AND process = 'AFG'
                            AND init_date between to_date(trunc(sysdate-1) || 
                            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                            ORDER BY ID;
                            FETCH c_afg INTO v_asd_trx;                            
                            IF (c_afg%NOTFOUND) THEN
                                v_process:=16;
                            ELSE
                                IF v_asd_trx.status = 'P' THEN
                                    v_process:=15;
                                ELSE 
                                    v_process:=14;
                                END IF;                                
                            END IF;
                            DBMS_OUTPUT.PUT_LINE (v_process);
                        CLOSE c_afg;
                    ELSE
                        IF v_asd_trx.status = 'P' THEN
                            v_process:=14;
                        ELSE 
                            v_process:=13;
                        END IF;                         
                        DBMS_OUTPUT.PUT_LINE (v_process);
                    END IF;
                CLOSE c_aur;
            ELSE
                IF v_asd_trx.status = 'P' THEN
                    v_process:=13;
                ELSE 
                    v_process:=12;
                END IF;              
                DBMS_OUTPUT.PUT_LINE (v_process);
            END IF;
        CLOSE c_aftp;
    ELSE
        IF v_asd_trx.status = 'P' THEN
            v_process:=12;
        ELSE 
            v_process:=10;
        END IF;        
        DBMS_OUTPUT.PUT_LINE (v_process);
    END IF;
CLOSE c_adel;

END;
/

EOF
)
if [[ ! -z $checkProcessGLCC ]]; then
if [ "$checkProcessGLCC" = "12" ]; then 
insertaADEL
elif [ "$checkProcessGLCC" = "13" ]; then 
insertaAFTP
elif [ "$checkProcessGLCC" = "14" ]; then 
insertaAUR
elif [ "$checkProcessGLCC" = "15" ]; then 
actualizaAFG
elif [ "$checkProcessGLCC" = "16" ]; then 
iniciaASD
elif [ "$checkProcessGLCC" = "10" ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Tienda ya procesada ' >> $current_log
fi
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | '$org_id' | Verifique los archivos de las Tiendas' >> $current_log
fi
##################################################
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Tienda ' >> $current_log
checkProcessCESATCC=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

v_asd_trx   asd.asd_acc_log%ROWTYPE;
v_process   NUMBER:=0;
c_adel      SYS_REFCURSOR;
c_aftp      SYS_REFCURSOR;
c_aur       SYS_REFCURSOR;
c_afg       SYS_REFCURSOR;

BEGIN

OPEN c_adel FOR
    SELECT *
    FROM asd.asd_acc_log
    WHERE organization = '$org_id'
    AND process = 'CDEL'
    AND init_date between to_date(trunc(sysdate-1) || 
    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    ORDER BY ID;
    FETCH c_adel INTO v_asd_trx;
    IF (c_adel%NOTFOUND) THEN
        OPEN c_aftp FOR
            SELECT *
            FROM asd.asd_acc_log
            WHERE organization = '$org_id'
            AND process = 'CFTP'
            AND init_date between to_date(trunc(sysdate-1) || 
            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
            ORDER BY ID;
            FETCH c_aftp INTO v_asd_trx;
            IF (c_aftp%NOTFOUND) THEN
                OPEN c_aur FOR
                    SELECT *
                    FROM asd.asd_acc_log
                    WHERE organization = '$org_id'
                    AND process = 'CUR'
                    AND init_date between to_date(trunc(sysdate-1) || 
                    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                    ORDER BY ID;
                    FETCH c_aur INTO v_asd_trx;
                    IF (c_aur%NOTFOUND) THEN
                        OPEN c_afg FOR
                            SELECT *
                            FROM asd.asd_acc_log
                            WHERE organization = '$org_id'
                            AND process = 'CFG'
                            AND init_date between to_date(trunc(sysdate-1) || 
                            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                            ORDER BY ID;
                            FETCH c_afg INTO v_asd_trx;                            
                            IF (c_afg%NOTFOUND) THEN
                                v_process:=16;
                            ELSE
                                IF v_asd_trx.status = 'P' THEN
                                    v_process:=15;
                                ELSE 
                                    v_process:=14;
                                END IF;                                
                            END IF;
                            DBMS_OUTPUT.PUT_LINE (v_process);
                        CLOSE c_afg;
                    ELSE
                        IF v_asd_trx.status = 'P' THEN
                            v_process:=14;
                        ELSE 
                            v_process:=13;
                        END IF;                         
                        DBMS_OUTPUT.PUT_LINE (v_process);
                    END IF;
                CLOSE c_aur;
            ELSE
                IF v_asd_trx.status = 'P' THEN
                    v_process:=13;
                ELSE 
                    v_process:=12;
                END IF;              
                DBMS_OUTPUT.PUT_LINE (v_process);
            END IF;
        CLOSE c_aftp;
    ELSE
        IF v_asd_trx.status = 'P' THEN
            v_process:=12;
        ELSE 
            v_process:=10;
        END IF;        
        DBMS_OUTPUT.PUT_LINE (v_process);
    END IF;
CLOSE c_adel;

END;
/

EOF
)
if [[ ! -z $checkProcessCESATCC ]]; then
if [ "$checkProcessCESATCC" = "12" ]; then 
insertaCDEL
elif [ "$checkProcessCESATCC" = "13" ]; then 
insertaCFTP
elif [ "$checkProcessCESATCC" = "14" ]; then 
insertaCUR
elif [ "$checkProcessCESATCC" = "15" ]; then 
actualizaCFG
elif [ "$checkProcessCESATCC" = "16" ]; then 
insertaCFG
elif [ "$checkProcessCESATCC" = "10" ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Tienda ya procesada ' >> $current_log
fi
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Verifique los archivos de las Tiendas' >> $current_log
fi

echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | CC | '$org_id' | Termina Tienda ' >> $current_log

done <"$2"

echo `(date +"%d/%m/%Y | %T | ")` ' CC | Termina Cash and Carry | ' $2 >> $current_log

elif [ "$1" = "NEXT" ]; then 
#conexion a base de datos ASD y ASM
. /opt/apps/batch/Asd_transactions/cfg/asd_conexion.sh
source /etc/profile

#Rutas
rutaout=/opt/apps/batch/Asd_transactions/out/
rutacfg=/opt/apps/batch/Asd_transactions/cfg/
rutabin=/opt/apps/batch/Asd_transactions/bin/

current_log="$3"

temporal_next=/opt/apps/batch/Asd_transactions/out/temporal_next.txt

insertaDAFG  () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | INICIA GENERACION DE ARCHIVOS DIRECT FULLFILMENT' >> $current_log
temp=$(echo "$temporal_next" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Buscando registros de la tienda  ' $STORE_NEXT >> $current_log
df_next=$(sqlplus -S $asdconexion << EOF
   set serveroutput on size 1000000; 
   set trimspool on;
   SET HEADING OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
   spool "$temp"  

DECLARE   

resultado SYS_REFCURSOR;
registro  varchar2(1000);

BEGIN	  

asd.asd_transactions_pkg.ejecuta_qry('Q_DF_NEXT','','$STORE_NEXT','',resultado); 

	loop
		fetch resultado into registro;
		exit when resultado%notfound;
		if trim(registro) = 'HDR|0|ASD|DF' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;
	end loop;

END;
/
   spool off; 
EOF
)
validaORA
if [[ ! -z $df_next ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Registros encontrados ... ' >> $current_log
creaarchivoGL
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | No se encontraron registros ... ' >> $current_log
rm -f $temp
fi
actualizaDAFG
}
creaarchivoGL () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inserta proceso DAFG' >> $current_log
SubinventoryNEXT=$(echo "$STORE_NEXT" | tr -d '[[:space:]]')
opus_file=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('DF GL','DAFG','P','GL',1,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 
    
END;
/

EOF
)
validaORA
if [ -z $opus_file ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DAFG' >> $current_log
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se inserto correctamente proceso DAFG' >> $current_log
opus_file=$(echo "$opus_file" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Obtiene nombre del archivo para GL' >> $current_log
archivoGL_NEXT=$(echo "$rutaout$opus_file" | tr -d '[[:space:]]')
archivoGL_NEXT=$(echo "$archivoGL_NEXT" | tr -d '\n')
#echo $df_next >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se crea archivo: '$archivoGL_NEXT >> $current_log
grep . $temp > $archivoGL_NEXT
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se creo el archivo correctamente: ' $archivoGL_NEXT >> $current_log
fi
}
actualizaDAFG () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza proceso DAFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Proceso DAFG' >> $current_log
update_DAFG=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DAFG','P','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DAFG ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DAFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DAFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Fin proceso DAFG' >> $current_log
insertaDAUR
fi
}
insertaDAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inicia proceso DAUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Proceso DAUR' >> $current_log
insert_DAUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DAUR','P','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 


END;
/

EOF
)
validaORA
if [ -z $insert_DAUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error al insertar proceso DAUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inserto correctamente proceso DAUR' >> $current_log
procesaDAUR
fi
}
procesaDAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza registros procesa DAUR' >> $current_log
process_DAUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('RECORDED DF','DAUR','','GL_DF',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $process_DAUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error al actualizar registros procesaDAUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza registros correctamente procesa DAUR' >> $current_log
actualizaDAUR
fi
}
actualizaDAUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza proceso DAUR' >> $current_log
update_DAUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DAUR','T','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DAUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DAUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DAUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Fin proceso DAUR' >> $current_log
insertaDAFTP
fi
}
insertaDAFTP() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inicia proceso DAFTP' >> $current_log
insert_DAFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DAFTP','P','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_DAFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error al insertar proceso DAFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inserto correctamente proceso DAFTP' >> $current_log
nextftpGL
fi
}
nextftpGL () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Envio de archivo por SFTP' >> $current_log
cd $rutacfg
sftpDF='ERROR-SFTP'
for fileDAFTP in "$insert_DAFTP"
do
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Parametro para SFTP...' $fileDAFTP >> $current_log
./sftpGL.sh $fileDAFTP >> $current_log
if [ $? -eq 0 ]; then
sftpDF='SUCCESS-SFTP'
else 
sftpDF='ERROR-SFTP'
fi
done
if [ $sftpDF = 'SUCCESS-SFTP' ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Envio por SFTP fue exitoso' >> $current_log
cd $rutabin
actualizaDAFTP
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error el envio por SFTP no fue exitoso' >> $current_log
fi
}
actualizaDAFTP () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza proceso DAFTP' >> $current_log
update_DAFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DAFTP','T','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DAFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DAFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DAFTP' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Fin proceso DAFTP' >> $current_log
insertaDADEL
fi
}
insertaDADEL() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inicia proceso DADEL' >> $current_log
insert_DADEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DADEL','P','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_DADEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error al insertar proceso DADEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Inserto correctamente proceso DADEL' >> $current_log
procesaDADEL
fi
}
procesaDADEL() {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Preparando archivos del File System DADEL' >> $current_log
fileDadel=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;

DECLARE

CURSOR c_count_adel is
SELECT COUNT(file_name)
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'DAFTP'
AND organization = '$STORE_NEXT'
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

CURSOR c_adel is
SELECT file_name
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'DAFTP'
AND organization = '$STORE_NEXT'
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

v_cout_adel     VARCHAR2(50):=NULL;
v_file          VARCHAR2(250):=NULL;

BEGIN

OPEN c_count_adel;
FETCH c_count_adel INTO v_cout_adel;
IF v_cout_adel <> '0' THEN
    OPEN c_adel;
    LOOP FETCH c_adel INTO v_file;
    EXIT WHEN c_adel%notfound;
        dbms_output.put_line( v_file );
    END LOOP;
    CLOSE c_adel;
ELSE
    dbms_output.put_line( 'N-ADEL' );
END IF;    
CLOSE c_count_adel;

END;
/

EOF
)
validaORA
if [ "$fileDadel" != "N-ADEL" ]; then
let recC=0
echo "${fileDadel}" | while read line
do
archivoDeleteD=$(echo "$rutaout$line" | tr -d '[[:space:]]')
if [ -f $archivoDeleteD ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se elimina el archivo: ' $archivoDeleteD >> $current_log
rm -f $archivoDeleteD
let recC=recC+1;
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | No se encontró el archivo, revisar con su administrador del sistema' >> $current_log
fi
done
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | No hay archivos a eliminar' >> $current_log
fi
actualizaDADEL
}
actualizaDADEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Actualiza proceso DADEL' >> $current_log
update_DADEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida1       ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DADEL','T','GL',0,v_files,'$STORE_NEXT',p_out_salida1);

FOR l_row IN 1 .. p_out_salida1.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida1(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DADEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DADEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DADEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Fin proceso ADEL' >> $current_log
fi
#insertaDCFG
}
##################################################
insertaDCFG  () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Buscando registros de la tienda  ' $org_id >> $current_log
temp=$(echo "$temporal_next" | tr -d '[[:space:]]')
df_c_next=$(sqlplus -S $asdconexion << EOF
   set serveroutput on size 1000000; 
   set trimspool on;
   SET HEADING OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
   spool "$temp"

DECLARE   

resultado SYS_REFCURSOR;
registro    varchar2(1000);

BEGIN	  
 
asd.asd_transactions_pkg.ejecuta_qry('Q_CESAT_DF','','','',resultado);   

	loop
		fetch resultado into registro;
		exit when resultado%notfound;
		if trim(registro) = 'HDR|0|ASD|DF' then
		  dbms_output.put_line(NULL);
		  exit;
		else
		  dbms_output.put_line( registro );
		end if;	
	end loop;

END;
/     
   spool off;
EOF
)
if [[ ! -z $df_c_next ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Registros encontrados ... ' >> $current_log
creaarchivoCESAT
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | No se encontraron registros ... ' >> $current_log
rm -f $temp
fi
actualizaDCFG
}
creaarchivoCESAT () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserta proceso DCFG' >> $current_log
cesat_file=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('DF CESAT','DCFG','P','CESAT',1,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $cesat_file ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DCFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se inserto correctamente proceso DCFG' >> $current_log
cesat_file=$(echo "$cesat_file" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Obtiene nombre del archivo para CESAT' >> $current_log
archivoCESAT_NEXT=$(echo "$rutaout$cesat_file" | tr -d '[[:space:]]')
archivoCESAT_NEXT=$(echo "$archivoCESAT_NEXT" | tr -d '\n')
#echo $df_c_next >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se crea archivo: '$cesat_file >> $current_log
grep . $temp > $archivoCESAT_NEXT
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se creo el archivo correctamente: ' $archivoCESAT_NEXT >> $current_log
fi
}
actualizaDCFG () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza proceso DCFG' >> $current_log
update_DCFG=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DCFG','P','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DCFG ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DCFG' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DCFG' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Fin proceso DCFG' >> $current_log
insertaDCUR
fi
}
insertaDCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inicia proceso DCUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserta proceso DCUR' >> $current_log
insert_DCUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DCUR','P','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_DCUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error al insertar proceso DCUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserto correctamente proceso DCUR' >> $current_log
procesaDCUR
fi
}
procesaDCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza registros procesaAUR' >> $current_log
process_DCUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('RECORDED DF','DCUR','','CESAT_DF',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $process_DCUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error al actualizar registros procesaDCUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza registros correctamente procesaDCUR' >> $current_log
actualizaDCUR
fi
}
actualizaDCUR () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza proceso DCUR' >> $current_log
update_DCUR=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DCUR','T','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DCUR ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DCUR' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DCUR' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Fin proceso CUR' >> $current_log
insertaDCFTP
fi
}
insertaDCFTP() {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inicia proceso DCFTP' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserta proceso DCFTP' >> $current_log
insert_DCFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DCFTP','P','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_DCFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error al insertar proceso DCFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserto correctamente proceso DCFTP' >> $current_log
nextftpCESAT
fi
}
nextftpCESAT () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Envio de archivo NEXT-CESAT por DCFTP' >> $current_log
cd $rutacfg
cesat_file=$(echo "$cesat_file" | tr -d '[[:space:]]')
cesat_file=$(echo "$cesat_file" | tr -d '\n')
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Parametro para SFTP...' $cesat_file >> $current_log
./sftpCESAT.sh $cesat_file >> $current_log
if [ $? -eq 0 ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Envio por DCFTP fue exitoso NEXT-CESAT' >> $current_log
cd $rutabin
actualizaDCFTP
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error el envio por DCFTP NEXT-CESAT no fue exitoso' >> $current_log
fi 
}
actualizaDCFTP () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza proceso DCFTP' >> $current_log
update_DCFTP=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DCFTP','T','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DCFTP ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DCFTP' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DCFTP' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Fin proceso DCFTP' >> $current_log
insertaDCDEL
fi
}
insertaDCDEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inicia proceso DCDEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserta proceso DCDEL' >> $current_log
insert_DCDEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('INSERTA DF','DCDEL','P','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $insert_DCDEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error al insertar proceso DCDEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Inserto correctamente proceso DCDEL' >> $current_log
procesaDCDEL
fi
}
procesaDCDEL (){
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Elimina archivos del File System DCDEL' >> $current_log
filecadelDF=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

CURSOR c_count_adel is
SELECT COUNT(file_name)
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'DCFTP'
AND organization = $STORE_NEXT
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

CURSOR c_adel is
SELECT file_name
FROM asd.asd_acc_log
WHERE status = 'T'
AND process = 'DCFTP'
AND organization = $STORE_NEXT
AND end_date between to_date( (sysdate-60) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS')
    AND to_date( (sysdate-31) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
ORDER BY ID;

v_cout_adel     VARCHAR2(50):=NULL;
v_file          VARCHAR2(250):=NULL;

BEGIN

OPEN c_count_adel;
FETCH c_count_adel INTO v_cout_adel;
IF v_cout_adel <> '0' THEN
    OPEN c_adel;
    LOOP FETCH c_adel INTO v_file;
    EXIT WHEN c_adel%notfound;
        dbms_output.put_line( v_file );
    END LOOP;
    CLOSE c_adel;
ELSE
    dbms_output.put_line( 'N-DCDEL' );
END IF;    
CLOSE c_count_adel;

END;
/

EOF
)
validaORA
if [ "$filecadelDF" != "N-DCDEL" ]; then
let recC=0
echo "${filecadelDF}" | while read line
do
archivoDeleteDF=$(echo "$rutaout$line" | tr -d '[[:space:]]')
if [ -f $archivoDeleteDF ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se elimina el archivo: ' $archivoDeleteDF >> $current_log
rm -f $archivoDeleteDF
let recC=recC+1;
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | No se encontró el archivo, revisar con su administrador del sistema' >> $current_log
fi
done
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | No hay archivos a eliminar' >> $current_log
fi
actualizaDCDEL
}
actualizaDCDEL () {
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Actualiza proceso DCDEL' >> $current_log
update_DCDEL=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

p_out_salida        ASD.OUT_FILES:=ASD.OUT_FILES();
v_files             ASD.IN_FILES:=ASD.IN_FILES();

BEGIN

asd.asd_transactions_pkg.inicio_prc('ACTUALIZA DF','DCDEL','T','CESAT',0,v_files,'$STORE_NEXT',p_out_salida);

FOR l_row IN 1 .. p_out_salida.COUNT
LOOP
    DBMS_OUTPUT.PUT_LINE (p_out_salida(l_row).description);
END LOOP; 

END;
/

EOF
)
validaORA
if [ -z $update_DCDEL ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Error no se inserta correctamente proceso DCDEL' >> $current_log
else 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Se actualizo correctamente proceso DCDEL' >> $current_log
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Fin proceso DCDEL' >> $current_log
fi
}
while IFS= read -r line
do
STORE_NEXT=$(echo "$line" | tr -d '[[:space:]]')
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Tienda ' >> $current_log
temporal=/opt/apps/batch/Asd_transactions/out/temporal"_$STORE_NEXT".txt
checkProcessGLDF=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

v_asd_trx   asd.asd_acc_log%ROWTYPE;
v_process   NUMBER:=0;
c_adel      SYS_REFCURSOR;
c_aftp      SYS_REFCURSOR;
c_aur       SYS_REFCURSOR;
c_afg       SYS_REFCURSOR;

BEGIN

OPEN c_adel FOR
    SELECT *
    FROM asd.asd_acc_log
    WHERE organization = '$STORE_NEXT'
    AND process = 'DADEL'
    AND init_date between to_date(trunc(sysdate-1) || 
    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    ORDER BY ID;
    FETCH c_adel INTO v_asd_trx;
    IF (c_adel%NOTFOUND) THEN
        OPEN c_aftp FOR
            SELECT *
            FROM asd.asd_acc_log
            WHERE organization = '$STORE_NEXT'
            AND process = 'DAFTP'
            AND init_date between to_date(trunc(sysdate-1) || 
            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
            ORDER BY ID;
            FETCH c_aftp INTO v_asd_trx;
            IF (c_aftp%NOTFOUND) THEN
                OPEN c_aur FOR
                    SELECT *
                    FROM asd.asd_acc_log
                    WHERE organization = '$STORE_NEXT'
                    AND process = 'DAUR'
                    AND init_date between to_date(trunc(sysdate-1) || 
                    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                    ORDER BY ID;
                    FETCH c_aur INTO v_asd_trx;
                    IF (c_aur%NOTFOUND) THEN
                        OPEN c_afg FOR
                            SELECT *
                            FROM asd.asd_acc_log
                            WHERE organization = '$STORE_NEXT'
                            AND process = 'DAFG'
                            AND init_date between to_date(trunc(sysdate-1) || 
                            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                            ORDER BY ID;
                            FETCH c_afg INTO v_asd_trx;                            
                            IF (c_afg%NOTFOUND) THEN
                                v_process:=16;
                            ELSE
                                IF v_asd_trx.status = 'P' THEN
                                    v_process:=15;
                                ELSE 
                                    v_process:=14;
                                END IF;                                
                            END IF;
                            DBMS_OUTPUT.PUT_LINE (v_process);
                        CLOSE c_afg;
                    ELSE
                        IF v_asd_trx.status = 'P' THEN
                            v_process:=14;
                        ELSE 
                            v_process:=13;
                        END IF;                         
                        DBMS_OUTPUT.PUT_LINE (v_process);
                    END IF;
                CLOSE c_aur;
            ELSE
                IF v_asd_trx.status = 'P' THEN
                    v_process:=13;
                ELSE 
                    v_process:=12;
                END IF;              
                DBMS_OUTPUT.PUT_LINE (v_process);
            END IF;
        CLOSE c_aftp;
    ELSE
        IF v_asd_trx.status = 'P' THEN
            v_process:=12;
        ELSE 
            v_process:=10;
        END IF;        
        DBMS_OUTPUT.PUT_LINE (v_process);
    END IF;
CLOSE c_adel;

END;
/

EOF
)
if [[ ! -z $checkProcessGLDF ]]; then
if [ "$checkProcessGLDF" = "12" ]; then 
insertaDADEL
elif [ "$checkProcessGLDF" = "13" ]; then 
insertaDAFTP
elif [ "$checkProcessGLDF" = "14" ]; then 
insertaDAUR
elif [ "$checkProcessGLDF" = "15" ]; then 
actualizaDAFG
elif [ "$checkProcessGLDF" = "16" ]; then 
insertaDAFG
elif [ "$checkProcessGLDF" = "10" ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Tienda ya procesada' >> $current_log
fi
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Verifique los archivos de las Tiendas' >> $current_log
fi
##################################################
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Tienda ' >> $current_log
checkProcessCESATDF=$(sqlplus -S $asdconexion << EOF
	SET serveroutput on size 1000000;
	SET trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	
DECLARE

v_asd_trx   asd.asd_acc_log%ROWTYPE;
v_process   NUMBER:=0;
c_adel      SYS_REFCURSOR;
c_aftp      SYS_REFCURSOR;
c_aur       SYS_REFCURSOR;
c_afg       SYS_REFCURSOR;

BEGIN

OPEN c_adel FOR
    SELECT *
    FROM asd.asd_acc_log
    WHERE organization = '$STORE_NEXT'
    AND process = 'DCDEL'
    AND init_date between to_date(trunc(sysdate-1) || 
    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    ORDER BY ID;
    FETCH c_adel INTO v_asd_trx;
    IF (c_adel%NOTFOUND) THEN
        OPEN c_aftp FOR
            SELECT *
            FROM asd.asd_acc_log
            WHERE organization = '$STORE_NEXT'
            AND process = 'DCFTP'
            AND init_date between to_date(trunc(sysdate-1) || 
            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
            ORDER BY ID;
            FETCH c_aftp INTO v_asd_trx;
            IF (c_aftp%NOTFOUND) THEN
                OPEN c_aur FOR
                    SELECT *
                    FROM asd.asd_acc_log
                    WHERE organization = '$STORE_NEXT'
                    AND process = 'DCUR'
                    AND init_date between to_date(trunc(sysdate-1) || 
                    ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                    ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                    ORDER BY ID;
                    FETCH c_aur INTO v_asd_trx;
                    IF (c_aur%NOTFOUND) THEN
                        OPEN c_afg FOR
                            SELECT *
                            FROM asd.asd_acc_log
                            WHERE organization = '$STORE_NEXT'
                            AND process = 'DCFG'
                            AND init_date between to_date(trunc(sysdate-1) || 
                            ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || 
                            ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
                            ORDER BY ID;
                            FETCH c_afg INTO v_asd_trx;                            
                            IF (c_afg%NOTFOUND) THEN
                                v_process:=16;
                            ELSE
                                IF v_asd_trx.status = 'P' THEN
                                    v_process:=15;
                                ELSE 
                                    v_process:=14;
                                END IF;                                
                            END IF;
                            DBMS_OUTPUT.PUT_LINE (v_process);
                        CLOSE c_afg;
                    ELSE
                        IF v_asd_trx.status = 'P' THEN
                            v_process:=14;
                        ELSE 
                            v_process:=13;
                        END IF;                         
                        DBMS_OUTPUT.PUT_LINE (v_process);
                    END IF;
                CLOSE c_aur;
            ELSE
                IF v_asd_trx.status = 'P' THEN
                    v_process:=13;
                ELSE 
                    v_process:=12;
                END IF;              
                DBMS_OUTPUT.PUT_LINE (v_process);
            END IF;
        CLOSE c_aftp;
    ELSE
        IF v_asd_trx.status = 'P' THEN
            v_process:=12;
        ELSE 
            v_process:=10;
        END IF;        
        DBMS_OUTPUT.PUT_LINE (v_process);
    END IF;
CLOSE c_adel;

END;
/

EOF
)
if [[ ! -z $checkProcessCESATDF ]]; then
if [ "$checkProcessCESATDF" = "12" ]; then 
insertaDCDEL
elif [ "$checkProcessCESATDF" = "13" ]; then 
insertaDCFTP
elif [ "$checkProcessCESATDF" = "14" ]; then 
insertaDCUR
elif [ "$checkProcessCESATDF" = "15" ]; then 
actualizaDCFG
elif [ "$checkProcessCESATDF" = "16" ]; then 
insertaDCFG
elif [ "$checkProcessCESATDF" = "10" ]; then 
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Tienda ya procesada ' >> $current_log
fi
else
echo `(date +"%d/%m/%Y | %T | ")` 'CESAT | DF | '$STORE_NEXT' | Verifique los archivos de las Tiendas' >> $current_log
fi

echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | '$STORE_NEXT' | Termina Tienda ' >> $current_log
done <"$2"

echo `(date +"%d/%m/%Y | %T | ")` ' DF | Termina Direct Fullfilment | ' $2 >> $current_log

fi