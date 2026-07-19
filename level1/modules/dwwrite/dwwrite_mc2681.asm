DWWrite             pshs      cc,a      ; preserve registers
                  IFEQ    NOINTMASK
                    orcc      #IntMasks ; mask interrupts
                  ENDC
D@01                lda       SR.D+8
                    anda      #%00000100 ; if transmit buffer is empty
                    beq       D@01
                    lda       ,x+
                    sta       TXRX.D+8
                    leay      -1,y      ; decrement byte counter
                    bne       D@01
                    puls      cc,a,pc
