#partial_hitbox=$(addprefix ./build/, $(notdir $(frames:.png=.lua)))
frames=$(addprefix ./build/, combat_idle.png\
				)
boundries=$(frames:.png=.lua)
info=info.lua
hitbox=hitbox.lua
sheet=sheet.png
nmap=normal.png

script_dir=../../../utilities/
texatlas_script=$(script_dir)/texatlas.py
generate_script=$(script_dir)/generate_animation.py
normal_script=$(script_dir)/normalmap.py

all: create_build_dirs $(sheet) $(hitbox)

$(hitbox): $(boundries)
	@echo "local data = {\n" > $@
	@cat $(boundries) >> $@
	@echo "}\nreturn data" >> $@

$(sheet): $(frames)
	@python $(texatlas_script) $^ -i $(info) -s $(sheet)
	@python $(normal_script) $(sheet) $(nmap)

./build/combat_idle.%: ./frame/combat_idle.png
	@python $(generate_script) -w 96 -e 55 -f $(@:.lua=.png) -l $(@:.png=.lua) $<


./build/suikia.%: ./frame/suikia.png
	@python $(generate_script) -w 74 -e 106 -f $(@:.lua=.png) -l $(@:.png=.lua) $<

create_build_dirs:
	@mkdir -p build

clean:
	@rm -rf build
	@rm -f $(info)
	@rm -f $(hitbox)
	@rm -f $(sheet)
	@rm -f $(nmap)
