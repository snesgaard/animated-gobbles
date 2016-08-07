target=gobbles
sheet=$(target:=/sheet.png)

all: $(sheet)

%.png:
	@cd $(dir $@)
	@make
	@cd ..
