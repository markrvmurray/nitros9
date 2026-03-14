* Timeout is implemented. Its a countdown of $7FFF with no delay while
* checking for available data in the DUART.
DWRead              pshs      d,x,u
                    pshs      cc
                    tfr       x,u       ; U now points to receive buffer
                    ldx       #$0000    ; initialise checksum
                  IFEQ    NOINTMASK
                    orcc      #IntMasks
                  ENDC
*
D@00                ldd       #$7FFF    ; initialise timeout
                    pshs      d         ; push timeout counter
D@01                ldb       SR.D+8
                    andb      #%00000001
                    bne       D@02      ; byte waiting?
                    ldd       ,s        ; .n decrement timeout
                    subd      #1
                    std       ,s
                    bne       D@01      ; if not timeout
                    leas      2,s       ; pop timeout counter
                    bra       D@Error
*
D@02                ldb       TXRX.D+8
                    stb       ,u+
                    abx                 ; accumulate checksum
                    leay      ,-y
                    beq       D@Done    ; all bytes received
                    ldd       #$7FFF    ; reset timeout for next byte
                    std       ,s
                    bra       D@01      ; next byte
D@Done              leas      2,s       ; pop timeout counter
                    bra       D@OK
*
D@Error             puls      cc
                    andcc     #~(Zero+Carry) ; ~Z = not all bytes received, ~C = no framing error
                    bra       D@Exit
*
D@OK                puls      cc
                    orcc      #Zero     ; Z = all bytes received
                    andcc     #~Carry   ; ~C = no framing error
D@Exit              tfr       x,y       ; return checksum in Y
                    puls      d,x,u,pc
