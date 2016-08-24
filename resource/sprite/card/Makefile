#partial_hitbox=$(addprefix ./build/, $(notdir $(frames:.png=.lua)))
frames=$(addprefix ./build/, potato.png\
				)
boundries=$(frames:.png=.lua)
info=info.lua
hitbox=hitbox.lua
sheet=sheet.png

script_dir=../../../utilities/
texatlas_script=$(script_dir)/texatlas.py
generate_script=$(script_dir)/generate_animation.py

all: create_build_dirs $(sheet) $(hitbox)

$(hitbox): $(boundries)
	@echo "local data = {\n" > $@
	@cat $(boundries) >> $@
	@echo "}\nreturn data" >> $@

$(sheet): $(frames)
	@python $(texatlas_script) $^ -i $(info) -s $(sheet)

./build/%.png: ./frame/%.png
	@python $(generate_script) -w 32 -e 27 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$<


create_build_dirs:
	@mkdir -p build

clean:
	@rm -rf build
	@rm -f $(info)
	@rm -f $(hitbox)
	@rm -f $(sheet)
	@rm -f $(nmap)
