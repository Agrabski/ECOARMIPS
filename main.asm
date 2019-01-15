	.data			
fname:	.asciiz "src_001.bmp"		# input file name
outfn:	.asciiz "result.bmp"		#"small.bmp"	"small - Copy.bmp" "src_001.bmp"
imgInf:	.word 782, 428, pImg, 0, 0, 0
handle: .word 0
fsize:	.word 0
pSize:	.word 	458760
# to avoid memory allocation image buffer is defined
# big enough to store 512x512 black&white image
# note that we know exactly the size of the header
# pImgae is the first byte of image itself
#Width =  ($a0) 		1st element of imgInfo
#Height = 4($a0) 		2nd element of imgInfo

pFile:		.space 62
		.align 2
pImg:		.space 36000
patternMask:	.word	0
stack:		.space	100
ptrn:	.byte		0x43, 0x7d, 0x7d, 0x41, 0x3d, 0x3d, 0x3d, 0x40# 	0x40, 0x3d, 0x3d, 0x3d, 0x41, 0x7d, 0x7d, 0x43		0x43, 0x7d, 0x7d, 0x41, 0x3d, 0x3d, 0x3d, 0x40
output: .word 	0:32
outc:	.word	0
	.text
.macro	push(%val)
		sw	%val, ($sp)
		addiu	$sp, $sp, 4
.end_macro
.macro	pop(%val)
		lw	%val, -4($sp)
		subiu	$sp, $sp, 4
.end_macro
main:	
	# open input file for reading
	# the file has to be in current working directory
	# (as recognized by mars simulator)
	la $sp, stack
	la $a0, fname
	li $a1, 0
	li $a2, 0
	li $v0, 13
	syscall
	# read the whole file at once into pFile buffer
	# (note the effective size of this buffer)
	move $a0, $v0
	sw $a0, handle
	la $a1, pFile
	la $a2, 36062
	li $v0, 14
	syscall
	# store file size for further use and print it
	move $a0, $v0
	sw $a0, fsize
	li $v0, 1
	syscall
	# close file
	li $v0, 16
	syscall
	
######################################
# instead of project implementation
# just set 8 pixels in row 0 and columns in range 0..7

	la 	$a0, imgInf
	lw 	$a1, pSize
	la 	$a2, ptrn
	la 	$a3, output
	la	$t0, outc
	push($t0)
	jal	findPatterns

######################################

	# open the result file for writing
	la $a0, outfn
	li $a1, 1
	li $a2, 0
	li $v0, 13
	syscall
	# print handle of the file 
	move $a0, $v0
	sw $a0, handle
	li $v0, 1
	syscall
	# save the file (file size is restored from fsize)
	la $a1, pFile
	lw $a2, fsize
	li $v0, 15
	syscall
	# close file
	li $v0, 16
	syscall
		
	li $v0, 10
	syscall
	
#(unsigned widith, int x, int y)
loadDoubleWord:	
		addiu	$a0, $a0, 31
		srl	$a0, $a0, 5
		sll	$a0, $a0, 2
		mulu	$a0, $a0, $a2	#Y offset
		
		addu	$a0, $a0, $a1	#X offset
		
		la	$v0, pImg
		addu	$v1, $a0, $v0	#calculate address
		
		lw	$v0, ($v1)	#load word into return
		lw	$v1, 4($v1)
		rol $t1,$v0,8         
li $t2,0x00FF00FF     # $t2 contains mask 0x00FF00FF
and $t3,$t1,$t2     # byte 0 and 2 valid
ror $t1,$v0,8       
not $t2,$t2        # $t2 contains mask 0xFF00FF00
and $t1,$t1,$t2     # byte 1 and 3 valid
or $v1,$t3,$t1      # little endian-number in $t3

rol $t1,$v1,8         
li $t2,0x00FF00FF     # $t2 contains mask 0x00FF00FF
and $t3,$t1,$t2     # byte 0 and 2 valid
ror $t1,$v1,8       
not $t2,$t2        # $t2 contains mask 0xFF00FF00
and $t1,$t1,$t2     # byte 1 and 3 valid
or $v1,$t3,$t1      # little endian-number in $t3
		jr	$ra
	

		
# 	$a0 = pImg
#	$a1 = pSize
#	$a2 = ptrn
#	$a3 = output

findPatterns:
		lw	$s7, -4($sp)
		move	$fp, $sp
		push($a0)
		push($a1)
		push($a2)
		push($a3)
		push($ra)
		move	$s0, $a1
		andi	$s0, $s0, 0xFF	#pattern height
		move	$t0, $a1
		andi	$t0, $t0, 0xFF0000	#pattern widith
		srl	$t0, $t0, 16
		push($t0)

		li	$t2, -1
						#build pattern mask
		li	$t1, 0
#NOCALL	
buildMask:	beqz	$t0, endBuldMask
		subu	$t0, $t0, 1
		sll	$t1, $t1, 1
		or	$t1, $t1, 1
		j	buildMask
		
#NOCALL
endBuldMask:	move	$s4, $t1
		sw	$t1, patternMask
		li	$s1, 0
		li	$s2, 0
		li	$s3, 0
		move	$s5, $a2
		move	$s6, $a3
						#pattern mask build
						#occupied registers:
						#	$s0 pattern height
						#	$s1 currentX
						#	$s2 currentY
						#	$s3 checked line
						#	$s4 patternMask
						#	$s5 pattern pointer
						#	$s6 result vector
						#	$s7 result count pointer
						#	$t9 maxN
						#	$t2 begin
				
		push($ra)			#$t8 pattern upper word
mainLoopBegin:	li	$t3, 0			#$t7 pattern lower word
		li	$t2, -1
		move	$t4, $s4
		move	$t9, $s5
		bltz	$s3, skipOffset	
		addu	$t9, $t9, $s3		#$t6 result upper word
skipOffset:	lb	$t7, ($t9)
		li	$t6, 0

						#$t5 result lower word
						#$t3 pattern mask upper word 
		#call loadWord			#$t4 pattern mask lower word
loadBuffer:	push($t1)
		push($t2)
		push($t3)
		lw	$a0, ($fp)
		lhu	$a0, ($a0)
		move	$a1, $s1
		move	$a2, $s2
		addu	$a2, $a2, $s3
		jal	loadDoubleWord
		pop($t3)
		pop($t2)
		pop($t1)

		
		
		
ptrnCheck:	
		and	$t5, $v0,$t4
		and	$t6, $v1,$t3
		xor	$t5, $t5, $t7
		xor	$t6, $t6, $t8
		
		bnez	$t5, patternNotFound
		bnez	$t6, patternNotFound
		
		#pattern found
		bltz	$t2, skipWithSaveBegin
		bne	$t2, $s3, advanceLine
		
		
		
		move	$t0, $s1
		sll	$t0, $t0, 19
		move	$t1, $s2
		or	$t0, $t0, $t1
		sw	$t0, ($s6)	#save result
		addiu	$s6, $s6, 4	#increment pointer
		lb	$t0, ($s7)
		addiu	$t0, $t0, 1
		sw	$t0, ($s7) 	#increment count
#NOCALL
patternNotFound:			#advance
		
		srl	$t9, $t7, 31		#t8 pattern upper word
		sll	$t8, $t8, 1		#t7 pattern lower word
		sll	$t7, $t7, 1		#t4 mask lower word
		or	$t8,$t8, $t9		#t3 mask upper word
		
		srl	$a0, $t3, 31
		bnez	$a0, nextWord
		srl	$t9, $t4, 31
		sll	$t3, $t3, 1
		sll	$t4, $t4, 1
		or	$t3, $t3, $t9
		
		j	ptrnCheck
skipWithSaveBegin:
		move	$t2, $s3
advanceLine:	addiu	$s3, $s3,1
		bne	$s3, $s0, noReset
		li	$s3, 0
noReset:	addu	$t9,$s5, $s3		#load new line
		lb	$t7,($t9)
		move	$t8, $t7		#copy new line to upper word
		
		lw	$t1, 20($fp)		#load pattern widith
		
		clz	$t9, $t4		#count lower bits of mask

		li	$t0, 32
		subu	$t0, $t0, $t1
		
		sllv	$t8, $t8, $t0		#shift upper word as much left as you can
		
		subu	$t0, $t0, $t9		#calculate offset from the right

		
		clz	$t9, $t3

		beqz	$t9, skipSR
		srl	$t8, $t8, 1
		subiu	$t9, $t9, 1
		srlv	$t8, $t8, $t9		#shift pattern upper word to proper position

skipSR:		sllv	$t7, $t7, $t0		#shift pattern lower word
		
		
		
		

		
		j	loadBuffer
		
nextWord:	addiu	$s1, $s1, 4
		lw	$t0, ($fp)
		lw	$t0, ($t0)
		divu	$t0, $t0, 8
		subu	$t0, $t0, $s1
		bgtz	$t0, mainLoopBegin
		li	$s1, 0
		addiu	$s2, $s2, 1
		lw	$t0, ($fp)
		lw	$t0, 4($t0)
		subu	$t0, $t0, $s0
		subu	$t0, $t0, $s2
		bgtz	$t0, mainLoopBegin
end:		
		lw	$ra, -4($sp)
		jr	$ra

