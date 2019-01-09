	.data
fname:	.asciiz "small.bmp"		# input file name
outfn:	.asciiz "result.bmp"	
imgInf:	.word 32, 32, pImg, 0, 0, 0
handle: .word 0
fsize:	.word 0
pSize:	.word 	458760
ptrn:	.word 	0x40, 0x3d, 0x3d, 0x3d, 0x41, 0x7d, 0x7d, 0x43
output: .word 	0:32
# to avoid memory allocation image buffer is defined
# big enough to store 512x512 black&white image
# note that we know exactly the size of the header
# pImgae is the first byte of image itself
#Width =  ($a0) 		1st element of imgInfo
#Height = 4($a0) 		2nd element of imgInfo

pFile:		.space 62
pImg:		.space 36000
patternMask:	.word	0
stack:		.space	100

	.text
.macro	push(%val)
		sw	%val, ($sp)
		addiu	$sp, $sp, 4
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
loadByte:	
		addiu	$a0, $a0, 31
		srl	$a0, $a0, 5
		sll	$a0, $a0, 2
		mulu	$a0, $a0, $a2	#Y offset
		
		addu	$a0, $a0, $a1	#X offset
		
		la	$v0, pImg
		addu	$v0, $a0, $v0	#calculate address
		
		lw	$v0, ($v0)	#load word into return
		jr	$ra
	
#retunrs 0 if match
#(WORD buffer,WORD pattern, unsigned n)
checkPattern:
		lw	$t1, patternMask
		srlv	$t1, $t1, $a2		#load and shift pattern mask to proper position
		
		and	$t1, $t1, $a0		#apply pattern mask to buffer
		
		xor	$v0, $t1, $a1		#xor with the pattern
		jr	$ra		
		
# 	$a0 = pImg
#	$a1 = pSize
#	$a2 = ptrn
#	$a3 = output

findPatterns:
		move	$fp, $sp
		push($a0)
		push($a1)
		push($a2)
		push($a3)
		move	$s0, $a1
		andi	$s0, $s0, 0xFFFF	#pattern height
		move	$t0, $a0
		andi	$t0, $t0, 0xFFFF0000	#pattern widith
		srl	$t0, $t0, 16
		move	$t9, $t0


						#build pattern mask
		li	$t1, 0
#NOCALL	
buildMask:	beqz	$t0, endBuldMask
		subu	$t0, $t0, 1
		sll	$t1, $t1, 1
		or	$t1, $t1, 1
		j	buildMask
#NOCALL
endBuldMask:	sw	$t1, patternMask
		li	$s1, 0
		li	$s2, 0
		li	$s3, 0
		move	$s5, $a1
		move	$s6, $a2
		move	$s7, $a3
						#pattern mask build
						#occupied registers:
						#	$s0 pattern height
						#	$s1 currentX
						#	$s2 currentY
						#	$s3 checked line
						#	$s4 n
						#	$s5 pattern pointer
						#	$s6 result vector
						#	$s7 result count pointer
						#	$t9 maxN
				
		push($ra)		
#NOCALL		n = 0
mainLoopBegin:	li	$s4, 0
		
		#call loadWord
		move	$a0, $a0
		move	$a1, $s1
		move	$a2, $s2
		jal	loadByte

		#call checkPattern
ptrnCheck:	move	$a0, $v0
		move	$a1, $s5
		addu	$a1, $a1, $s3
		lw	$a1, ($a1)
		move	$a2, $s4
		jal	checkPattern
		
		
		beqz	$v0, patternNotFound
		
		
		move	$t0, $s1
		sll	$t0, $t0, 19
		move	$t1, $s2
		or	$t0, $t0, $t1
		sw	$t0, ($s5)	#save result
		addiu	$s5, $s5, 4	#increment pointer
		lb	$t0, ($s7)
		addiu	$t0, $t0, 1
		sw	$t0, ($s7) 	#increment count
#NOCALL
patternNotFound:			#advance
		
		
		addiu	$s4, $s4, 1	#n++
		li 	$t0, 32
		subu	$t0, $t0, $t9
		bne	$s4, $t0 ptrnCheck
		
		addiu	$s1, $s1, 3
		lw	$t0, imgInf
		srl	$t0,$t0, 3
		subiu	$t0,$t0, 3
		blt	$s1,$t0, mainLoopBegin
		li	$s1, 0
		addiu	$s2, $s2, 1
		la	$t0, ($fp)
		lw	$t0, 4($t0)
		blt	$t0,$s2, end
		j	mainLoopBegin
end:		
		lw	$ra, -4($sp)
		jr	$ra

