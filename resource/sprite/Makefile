target=gobbles card engineer portrait prop sfx witch gungoblin icon
clean_target = $(target:%=clean-%)
# %sheet=$(target:=/sheet.png)

all: $(target)
$(target):
	make -C $@

clean: $(clean_target)
$(clean_target):
	make -C $(@:clean-%=%) clean

.PHONY: all $(target)
