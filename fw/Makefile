FW_DATE := $(shell date +%Y%m%d%H%m%S)
FW_FILENAME := fw_$(FW_DATE).img

default: fw.img
	mv fw.img $(FW_FILENAME)
	zip $(FW_FILENAME).zip $(FW_FILENAME)

fw.img:
	mix firmware.image

