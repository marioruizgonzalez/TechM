WHENEVER SQLERROR EXIT

REVOKE EXECUTE ON ASD.TELEFONOS_TBL_TYP TO ASD_APP;
REVOKE EXECUTE ON ASD.REPORTE_MIGRACION_PKG TO ASD_APP;
/

WHENEVER SQLERROR CONTINUE;
