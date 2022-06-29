*---------------------------------------------------------------------*
*    view related data declarations
*   generation date: 28.06.2022 at 20:17:25
*   view maintenance generator version: #001407#
*---------------------------------------------------------------------*
*...processing: ZHU_PMAT........................................*
DATA:  BEGIN OF STATUS_ZHU_PMAT                      .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZHU_PMAT                      .
CONTROLS: TCTRL_ZHU_PMAT
            TYPE TABLEVIEW USING SCREEN '0003'.
*.........table declarations:.................................*
TABLES: *ZHU_PMAT                      .
TABLES: ZHU_PMAT                       .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
