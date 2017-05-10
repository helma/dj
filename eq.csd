<CsoundSynthesizer>
<CsOptions>
-+rtaudio=jack -b 128 -B 1048 -i adc -o dac -+jack_outportname=system:playback_
-+rtmidi=alsa -Mhw:3,0,0 ; input
-Qhw:3,0,0 ; output
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1


instr eq
;OUTPUT		OPCODE	CHANNEL | CTRLNUMBER | MINIMUM | MAXIMUM | Table nr_USED_TO_REMAP_SLIDER_VALUES (optional)
; http://subsynth.sourceforge.net/midinote2freq.html
          initc14     1, 0, 32, 0
khpn      ctrl14      1, 0, 32, 0, 124 ; 0 - 10 000 Hz
          initc14     1, 1, 33, 0.5
kcn       ctrl14      1, 1, 33, 37, 117 ; 70-7000 Hz
          initc14     1, 2, 34, 0.25
kgain     ctrl14      1, 2, 34, 0.1, 4 ; -20/+8 dB 0.1: 20 dB cut, 4: 12 dB boost
          initc14     1, 3, 35, 1
klpn      ctrl14      1, 3, 35, 71, 127 ; 500 - inf Hz
;          initc14     1, 7, 39, 0
;klpq      ctrl14      1, 7, 39, 0, 1 ; 
;keqq       ctrl17      1, 6, 20, 20000 

; initialize sc4
          outic 1, 0, 0, 0, 124 ; hpf
          outic 1, 32, 0, 0, 124 ; hpf
          outic 1, 2, 0.25, 37, 117 ; eqf
          outic 1, 34, 0, 37, 117 ; eqf
          ;outic 1, 3, kgain, 0.1, 4 ; eqgain
          outic 1, 3, 127, 71, 127 ; lpf
          outic 1, 35, 127, 71, 127 ; lpf

; frequency conversion
khpf      cpsmidinn  khpn
kcf       cpsmidinn  kcn
klpf      cpsmidinn  klpn
kbw       =          kcf/2 ; bw = f/q;  q=1

printk2 kgain
printk2 kcf

ain1,ain2 ins
if (khpn == 0) then ; turn off hpf
ahp1      =   ain1
ahp2      =   ain2
else
ahp1      mvchpf     ain1, khpf	
ahp2      mvchpf     ain2, khpf	
endif
aeq1    	eqfil      ahp1, kcf, kbw, kgain
aeq2    	eqfil      ahp2, kcf, kbw, kgain
if (klpn == 127) then ; turn off lpf
alp1      =   aeq1
alp2      =   aeq2
else
alp1      moogladder   aeq1, klpf, 0
alp2      moogladder   aeq2, klpf, 0
;alp1      mvclpf3   aeq1, klpf, klpq
;alp2      mvclpf3   aeq2, klpf, klpq
endif
          outs       alp1, alp2

endin

</CsInstruments>
<CsScore>
;1 0 z
i 1 0 3600
</CsScore>
</CsoundSynthesizer>
