#partial_hitbox=$(addprefix ./build/, $(notdir $(frames:.png=.lua)))
frames=$(addprefix ./build/, furnace_blade_A.png furnace_blade_B.png idle.png \
					walk.png run.png ascend.png descend.png blast_A.png\
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

./build/blast_A.%: ./frame/blast_A.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/descend.%: ./frame/descend.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/ascend.%: ./frame/ascend.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/run.%: ./frame/run.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/walk.%: ./frame/walk.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/idle.%: ./frame/idle.png
	@python $(generate_script) -w 32 -e 32 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/furnace_blade_A.%: ./frame/furnace_blade_A.png
	@python $(generate_script) -w 64 -e 64 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))

./build/furnace_blade_B.%: ./frame/furnace_blade_B.png
	@python $(generate_script) -w 64 -e 64 -f $(@:.lua=.png) -l $(@:.png=.lua) \
	 														$< $(addprefix ./boundry/, $(notdir $<))


create_build_dirs:
	@mkdir -p build

clean:
	@rm -rf build
	@rm -f $(info)
	@rm -f $(hitbox)
	@rm -f $(sheet)
	@rm -f $(nmap)
