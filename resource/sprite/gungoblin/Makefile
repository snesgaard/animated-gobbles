#partial_hitbox=$(addprefix ./build/, $(notdir $(frames:.png=.lua)))
frames=$(addprefix ./build/, idle.png throw.png\
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

./build/idle.%: ./frame/idle.png
	@python $(generate_script) -t 1.0 -w 60 -e 60 -f $(@:.lua=.png)\
					-l $(@:.png=.lua) $< $(addprefix ./boundry/, $(notdir $<))

./build/throw.%: ./frame/throw.png
	@python $(generate_script) -t 0.75 -w 100 -e 60 -f $(@:.lua=.png)\
					-l $(@:.png=.lua) $< $(addprefix ./boundry/, $(notdir $<))

create_build_dirs:
	@mkdir -p build

clean:
	@rm -rf build
	@rm -f $(info)
	@rm -f $(hitbox)
	@rm -f $(sheet)
	@rm -f $(nmap)
