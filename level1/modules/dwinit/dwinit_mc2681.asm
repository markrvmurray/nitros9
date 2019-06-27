DWInit
               pshs      a
               lda       #$CC              ; 38400 baud
               sta       CSR.D+8
               lda       #$10              ; Reset pointer to MR1X
               sta       CR.D+8
               lda       #$93              ; Set 8-bit No Parity, Rx controls RTS
               sta       MR.D+8
               lda       #$17              ; Set CTS enable Tx, 1 stop bit
               sta       MR.D+8
               puls      a,pc
