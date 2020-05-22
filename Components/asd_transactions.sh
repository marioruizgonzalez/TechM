#!/bin/bash
# -*- encoding: utf-8 -*-
#asd_transactions
##########FLUJO CASH AND CARRY##########
v_exit_CC='FALSE'
v_exit_DF='FALSE'

rutaclt=/opt/apps/batch/Asd_transactions/clt/
rutalog=/opt/apps/batch/Asd_transactions/log/

echo `(date +"%d/%m/%Y | %T | ")` 'DIR | Preparando directorio CLT para tiendas...'

limpiaDIRS () {
echo `(date +"%d/%m/%Y | %T | ")` 'DIR | Limpiando directorio CLT...'
if [ -z "$(ls -A $rutaclt)" ]; then
echo `(date +"%d/%m/%Y | %T | ")` 'DIR | El directorio se encuentra vacio...'
else
for archhivosT in "$rutaclt"*
do
echo `(date +"%d/%m/%Y | %T | ")` 'DIR | Eliminando ' "$archhivosT"
rm -rf $archhivosT
done
echo `(date +"%d/%m/%Y | %T | ")` 'DIR | Limpiando directorio LOG...'
oldLogs=$(find "$rutalog" -mtime +90 -exec rm {} \;)
echo `(date +"%d/%m/%Y | %T | ")` 'DIR | Realizado...'
fi
}

validaExit(){
if [ `grep "FALSE" $current_log | wc -l` -gt 0 ]; then
exit 1
else
exit 0
fi
}

limpiaDIRS

if [ "$1" = "AVS" ]; then
current_log="/opt/apps/batch/Asd_transactions/log/logCC`(date +"%d%m%y%H%M")`.log"
echo `(date +"%d/%m/%Y | %T | ")` 'CC | Inicio asd_transactions fecha del servidor: ' >> $current_log

#Rutas
rutaout=/opt/apps/batch/Asd_transactions/out/
rutacfg=/opt/apps/batch/Asd_transactions/cfg/
rutabin=/opt/apps/batch/Asd_transactions/bin/

#Bash
pOrg=/opt/apps/batch/Asd_transactions/bin/procesa_org.sh

#conexion a base de datos ASD
. /opt/apps/batch/Asd_transactions/cfg/asd_conexion.sh
. /opt/apps/batch/Asd_transactions/cfg/monitorAsd.sh $1
source /etc/profile

temporal=/opt/apps/batch/Asd_transactions/clt/temporalCC.txt

echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | Buscando tiendas por procesar...' >> $current_log
temp=$(echo "$temporal" | tr -d '[[:space:]]')
storeCC=$(sqlplus -S $asdconexion  << EOF
   set serveroutput on size 1000000; 
   set trimspool ON;
   SET SQLBLANKLINES ON;
   SET HEAD OFF;
   SET FEEDBACK OFF; 
   SET LINESIZE 200;
   spool "$temp"

SELECT DISTINCT ac.organization ORG
FROM asd.asd_accounting         ac
    , asd.asd_contract_order    aco
WHERE ( ac.insert_date between to_date(trunc(sysdate-1) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
        OR
       ac.assignment_date between to_date(trunc(sysdate-1) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    )
    AND ac.order_id         =   aco.order_id
    AND aco.order_flow      =   'CC'
    AND ac.recorded         is null
ORDER BY ORG ASC;

spool off;

EOF
)
if [[ ! -z $storeCC ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | Copiando tiendas en el archivo' >> $current_log
sed -i -e "1d" $temp
cd $rutaclt
split -l 200 $temp tiendasCC
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | Generando archivos con 200 tiendas para procesar' >> $current_log
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | Se crearon los archivos  -> tiendas <- ' >> $current_log
cd $rutabin
for fileCC in "$rutaclt"*
do
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | Archivo:' $fileCC >> $current_log
$pOrg $1 $fileCC $current_log &
done
#################### I N I C I O  V E R I F I C A  P R O C E S O S  A C T I V O S ####################
pOrg_cmp=procesa_org.sh
countprOg=`ps -fea | grep $pOrg_cmp | grep -v grep | wc -l`
while [ $countprOg != "0" ]
do
sleep $cSleep
countprOg=`ps -fea | grep $pOrg_cmp | grep -v grep | wc -l`
echo `(date +"%d/%m/%Y | %T | ")` 'EJECUCION | Espere por favor aun hay procesos ejecutandose ' >> $current_log
done
#################### F I N  V E R I F I C A  P R O C E S O S  A C T I V O S ####################
validaExit
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | CC | No se encontraron resultados de Tiendas, por favor verifique...' >> $current_log
fi
##########FLUJO DIRECT FULLFILMENT##########
elif [ "$1" = "NEXT" ]; then 
current_log="/opt/apps/batch/Asd_transactions/log/logDF`(date +"%d%m%y%H%M")`.log"

#Rutas
rutaout=/opt/apps/batch/Asd_transactions/out/
rutacfg=/opt/apps/batch/Asd_transactions/cfg/
rutabin=/opt/apps/batch/Asd_transactions/bin/

#Bash
pOrg=/opt/apps/batch/Asd_transactions/bin/procesa_org.sh

#conexion a base de datos ASD
. /opt/apps/batch/Asd_transactions/cfg/asd_conexion.sh
. /opt/apps/batch/Asd_transactions/cfg/monitorAsd.sh $1
source /etc/profile

temporal=/opt/apps/batch/Asd_transactions/clt/temporalDF.txt

echo `(date +"%d/%m/%Y | %T | ")` 'DF | Buscando tiendas por procesar...' >> $current_log
temp=$(echo "$temporal" | tr -d '[[:space:]]')
storeDF=$(sqlplus -S $asdconexion  << EOF
	set serveroutput on size 1000000; 
	set trimspool ON;
	SET SQLBLANKLINES ON;
	SET HEAD OFF;
	SET FEEDBACK OFF; 
	SET LINESIZE 200;
	spool "$temp"

SELECT DISTINCT ac.organization ORG
FROM  asd.asd_accounting        ac
    , asd.asd_contract_order    aco
WHERE ac.order_id       =   aco.order_id
    AND aco.suffix          in  ('ADF','NOR','CC','CC_PO','AVS_PO')
    AND ac.recorded     is null
    AND ( ac.insert_date between to_date(trunc(sysdate-1) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
        OR
       ac.assignment_date between to_date(trunc(sysdate-1) || ' 00:00:00','DD/MM/RRRR HH24:MI:SS') and to_date(trunc(sysdate-1) || ' 23:59:59','DD/MM/RRRR HH24:MI:SS')
    )
ORDER BY ORG ASC;

spool off;

EOF
)
if [[ ! -z $storeDF ]]; then
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | Copiando tiendas en el archivo' >> $current_log
sed -i -e "1d" $temp
cd $rutaclt
split -l 10 $temp tiendasDF
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | Generando archivos con 10 tiendas para procesar' >> $current_log
rm -f $temp
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | Se crearon los archivos  -> tiendas <- ' >> $current_log
cd $rutabin
for fileDF in "$rutaclt"*
do
echo `(date +"%d/%m/%Y | %T | ")` 'GL | DF | Archivo: ' "$fileDF" >> $current_log
$pOrg $1 $fileDF $current_log &
done
#################### I N I C I O  V E R I F I C A  P R O C E S O S  A C T I V O S ####################
pOrg_cmp=procesa_org.sh
countprOg=`ps -fea | grep $pOrg_cmp | grep -v grep | wc -l`
while [ $countprOg != "0" ]
do
sleep $cSleep
countprOg=`ps -fea | grep $pOrg_cmp | grep -v grep | wc -l`
echo `(date +"%d/%m/%Y | %T | ")` 'EJECUCION | Espere por favor aun hay procesos ejecutandose ' >> $current_log
done
#################### F I N  V E R I F I C A  P R O C E S O S  A C T I V O S ####################
validaExit
else
echo `(date +"%d/%m/%Y | %T | ")` 'GL | GL | DF | No se encontraron resultados de Tiendas, por favor verifique...' >> $current_log
fi
fi