#-------------------------------------------------------------------------------
#
# Kevin L. Pauba
# klpauba[at]gmail[dot]com
#
# Portions of code was lifted from the TF Rubies
#  Copyright (c) 2008 - 2014 Clark Bremer
#  clarkbremer@gmail.com
#
#-------------------------------------------------------------------------------



module KLP::Plugins::SolidsMakeShopDrawing

  # require File.join(PATH, "..", "tt_solid_inspector2", "error_finder.rb")
  # require File.join(PATH, "..", "ene_solids", "solids.rb")
  
  MODEL_OFFSET = 0
  SIDE_SPACING = 30

  class SolidsMakeShopDrawingTool
    @primary = nil
    # @intersecting_group = nil
      
    # Called when class is loaded
    def initialize
      unless Sketchup.is_pro?
        UI.messagebox("This plugin requires support for solids that is only available in the Pro Version.")
        return
      end
      
      model = Sketchup.active_model
      ss = model.selection
      if ss.size != 1
        Sketchup.set_status_text("Choose exactly one timber component")
      end
    end

    # Called when this tool is chosen
    def activate
      model = Sketchup.active_model
      ss = model.selection
      if ss.size == 1 && ss[0].manifold?
        original = ss[0]

        if not original.parent == model
          UI.messageBox "Solids Make Shop Drawings: Timber must not be part of a component or group"
          return
        end

        model.start_operation("SolidsMakeShopDrawing", true)

        view = model.active_view
        camera = view.camera
        context = {
          eye: camera.eye,
          target: camera.target,
          up: camera.up,
          perspective: camera.perspective?,
          fov: camera.fov,
          xray: model.rendering_options["ModelTransparency"],
          sky: model.rendering_options["DrawHorizon"]
        }
        
        tdims = Array.new
        # get_dimensions(original, min_extra_timber_length, metric, roundup, tdims)
        get_dimensions(original, 0, false, true, tdims)
        begin
          drawing = Array.new(4)

          # Copy the drawing and make it unique so as not to change the original selected timber.
          drawing[0] = model.entities.add_instance(original.definition, original.transformation)
          drawing[0].make_unique
          @primary = drawing[0]  # the primary is now the copy of the selected timber

          #
          # Find all solids that intersect with the primary component
          #
          volume = @primary.volume
          timbers = intersecting_solids(@primary, model.entities)

          #
          # Now remove any of the intersecting solids that are glued to any
          # tenons on the primary component.
          #
          primary_bb = @primary.bounds
          mortise_volume = {}
          timbers.each { |timber|
            # puts "@primary " + @primary.to_s + " intersects with entity " + timber.to_s
            mortise_name = timber.name
            if timber.is_a?(Sketchup::ComponentInstance)
              mortise_name = timber.definition.name
            end

            bbox = primary_bb.intersect(timber.bounds)
            # print("BBox:\n")
            # [ 0, 1, 2, 3, 4, 5, 6, 7].each { |i|
            #   print("\t", i, ": ", bbox.corner(i).to_s, "\n")
            # }
            if bbox.valid?
              if mortise_name.start_with?('Peg', 'peg') || verticies_in_bbox(@primary, bbox) < verticies_in_bbox(timber, bbox)
                #
                # The primary timber has fewer verticies in the bounding box than
                # the target timber it can be "trimmed" to yield the mortise.
                #
                if mortise_name.start_with?('Peg', 'peg')
                  print("Primary Vs:", verticies_in_bbox(@primary, bbox), "\n")
                  print("Peg Vs:", verticies_in_bbox(timber, bbox), "\n")

                  # TODO: Add a circle to the face of the primary
                  #       group that is coincident with the peg (both
                  #       sides). This will then allow the peg hole to
                  #       exist as a circle instead of individual (but
                  #       connected) lines.  We can then easily add a
                  #       construction point at the center to simplify
                  #       dimensioning.
                  #
                  #       Maybe find each circular face at the end of
                  #       the peg, find its center along with a vector
                  #       pointing toward the primary instance.  Then
                  #       use model.raytest() to determine the point
                  #       on primary where that marks the center of
                  #       the peg.  Record this location and use it to
                  #       create crosshairs on the drawing.
                  #

                  #
                  # Trim the peg to the size of the original timber
                  #
                  # Find the two faces of the pegs with the smallest
                  # area.
                  faces = timber.definition.entities.grep(Sketchup::Face)
                  areas = faces.map { |f| f.area }
                  min, max = areas.minmax
                  peg_faces = faces.select { |f| (f.area - min).abs < 0.001 }
                  if peg_faces.size != 2
                    print("Odd, ", peg_faces.size, " peg faces!\n")
                  end

                  # Now, use the center of the face bounding box and
                  # the reversed normal vector to find the
                  # intersecting point on the face of the original
                  # timber
                  mod = Sketchup.active_model
                  cpoints = Array.new
                  peg_faces.each { |f|
                    pc = Geom::Point3d.new(f.bounds.center)
                    pv = Geom::Vector3d.new(f.normal.reverse)
                    pc.transform!(timber.transformation)
                    pv.transform!(timber.transformation)
                    
                    print("Found Peg face: ", f.to_s, ", area: ", f.area, ", center: ", pc.to_s, "\n")

                    item = mod.raytest([pc, pv], true)
                    if item
                      pc = item[0]
                      c = item[1][0]
                      print("Peg face ", f, " intersected component ", c.to_s, " at ", pc, " (@primary=", @primary.to_s, ", original=", original.to_s, ", timber=", timber.to_s, ")\n")
                      next unless c == original || c == @primary
                      
                      # tr = c.transformation.inverse * timber.transformation
                      tr = c.transformation.inverse
                      # pv.transform!(tr)
                      pc.transform!(tr)
                      # pc.transform!(Geom::Transformation.translation(pv.length=d))
                      print("pc2:" + pc.to_s + "\n")
                      # cpoints.push(pc)

                      if @primary.is_a?(Sketchup::ComponentInstance)
                        ents = @primary.definition.entities
                      elsif @primary.is_a?(Sketchup::Group)
                        ents = @primary.entities
                      end
                      ents.add_cpoint(pc)
                    else
                      print("raytest failed!\n")
                    end
                  }
                  
                  # if @primary.is_a?(Sketchup::ComponentInstance)
                  #   ents = @primary.definition.entities
                  # else
                  #   ents = @primary.entities
                  # end
                  # cpoints.each { |pc| ents.add_cpoint(pc) }
                  next
                else
                  # print("Now trim the primary timber with the target timber \"", mortise_name, "\"\n")
                  grp = timber.trim(@primary)
                end
                if mortise_name
                  mortise_volume[mortise_name] = volume - grp.volume
                  if mortise_name.start_with?('Peg', 'peg')
                    print("\tPeg hole volume:", mortise_volume[mortise_name], "\n")
                  else
                    print("\t", mortise_name, " mortise volume:", mortise_volume[mortise_name], "\n")
                  end
                end

                volume = grp.volume
                @primary = grp
                Sketchup.active_model.definitions.purge_unused
              # else
              #   print("Ignore timber \"", timber.name, "\" since it doesn't protrude into the selected primary\n")
              end
            end
          }

          #
          # TODO: Add centerpoints to all circles and arcs (for future dimensioning)
          #
          # NOTE: after trimming, any circles or arcs (that are left
          #       from peg holes, for instance) are not actually a
          #       circle/arc -- they are a set of connected line
          #       segments.  We have to check an edge to set if all of
          #       the connecting edges are equal length and form a
          #       closed polygon or arc.  If so, we calculate the
          #       center point and put a construction point there.
          #
          
          drawing[0] = @primary	# the solid "trim" creates a new group and the original component was deleted

          lay_down_on_red(drawing[0], false)
          bbox = drawing[0].bounds
          tv = Geom::Vector3d.new(0, MODEL_OFFSET, (-1)*bbox.corner(0).z)
          tt = Geom::Transformation.translation(tv)
          drawing[0].transform!(tt)
          
          # Now make the other sides
          rv = Geom::Vector3d.new(0,0,0)    #rotation vector
          
          roll_angle = -90.degrees
          for i in 1..3 
            ### Dupe It
            drawing[i] = model.entities.add_instance(drawing[i-1].definition, [0,0,0])    
            # apply same transform to new comp.
            drawing[i].transformation = drawing[i-1].transformation;                 
            
            ### Offset it from the previous one  
            tv = Geom::Vector3d.new(0, 0, SIDE_SPACING)
            tt = Geom::Transformation.translation(tv)
            drawing[i].transform!(tt)
            
            ### Rotate it 90 degrees around the center of the component, parallel to red
            rv.set!(1,0,0)   
            ra = roll_angle                      
            rt = Geom::Transformation.rotation(drawing[i].bounds.center, rv, ra) 
            drawing[i].transform!(rt)
            drawing[i].make_unique
          end

          camera = Sketchup::Camera.new
          camera.perspective = false
          up = camera.up
          up.set!(0, 0, 1)  # level
          target = camera.target
          target.set!(MODEL_OFFSET, 0, SIDE_SPACING * 1.5) # parallel to y axis
          eye = camera.eye
          eye.set!(MODEL_OFFSET, -1000, SIDE_SPACING * 1.5)
          camera.set(eye, target, up)
          view.camera = camera

          model.rendering_options["DrawHorizon"] = false

          # company_name = Sketchup.read_default("TF", "company_name", "Company Name")
          company_name = 'OWTF'
          if original.name == ""
            timber_name = original.definition.name+"  (qty "+ original.definition.count_instances.to_s + ")"
            drawing_name = original.definition.name + ".skp"
          else
            timber_name = original.name
            drawing_name = original.name + ".skp"
          end
          tsize = tdims[0].to_s + " x " + tdims[1].to_s + " x " + tdims[3].to_s  
tm = Time.now  
          ts = tm.strftime("Created on: %m/%d/%Y")  
          # drawing_title = company_name + "\nProject: " + model.title + "\nTimber: " + timber_name + " - " + tsize + "\n" + ts + "\n"

          # Remove all entities that are not part of the drawings
          #
          # NOTE: Sketchup crashes if a e.erase! so we must generate a
          #       list of victims to erase from the model.
          #       Unfortunately, trying to erase all of the target
          #       entities from the model (using
          #       model.entities.erase_entities(victims)) also causes
          #       Sketchup to crash.  After many experiments, I found
          #       that it succeeds after executing UI.messagebox() --
          #       or any UI method whatsoever.  Therefore, I moved The
          #       code to erase the victims after the UI.savepanel()
          #       below.
          #
          victims = Array.new
          model.entities.each do |e|
            next if drawing.include?(e)
            victims.push(e)
          end

          # Now put only the drawings in the selection
          ss.clear
          drawing.each { |d| ss.add(d) }
          view.zoom(ss)
          ss.clear

          # model.add_note(drawing_title, 0.01, 0.02)
          begin
            sd_file = UI.savepanel("Save Shop Drawings", "",drawing_name)

            model.entities.erase_entities(victims)	# NOTE: moved this to after the UI.* call; otherwise it crashes

            if sd_file 
              while sd_file.index("\\")
                sd_file["\\"]="/"
              end
              print("saving shop drawings as:"+sd_file + "\n")
              save_status = model.save_copy(sd_file)
              if not save_status
                UI.messagebox("TF Rubies: Error saving Shop Drawings!")
              end
            else      
              UI.messagebox("Shop Drawings NOT saved!")
            end
          rescue
            print("TF Rubies: Error creating shop drawings: " + $!.message + "\n")
            UI.messagebox("TF Rubies: Error creating shop drawings: " + $!.message)
          ensure
            # now put everyting back the way we found it!
            # puts "putting it back"
            model.commit_operation
            Sketchup.undo      
            model = Sketchup.active_model
            view = model.active_view
            cam = view.camera
            cam.set(context[:eye], context[:target], context[:up])
            cam.perspective = context[:perspective]
            cam.fov = context[:fov]
            model.rendering_options["ModelTransparency"]= context[:xray]
            model.rendering_options["DrawHorizon"]= context[:sky]
            model.definitions.purge_unused
          end
        end
      elsif ss.size != 1
        puts "Exactly one component/group must be selected"
      else
        puts "Selection isn't a solid!"
      end
    end

    def deactivate(view)
      view.invalidate
    end

    def entities(e)
      if e.is_a?(Sketchup::Group)
        ents = e.entities
      else
         ents = e.definition.entities
      end
      return ents
    end
         
    def lay_down_on_red(timber, make_dir_lables = false)
      # fix the orientation so that its horizontal parallel with red
      # do this in two steps so that timbers at an angle don't "roll"
      
      red = Geom::Vector3d.new(1,0,0) 
      green = Geom::Vector3d.new(0,1,0) 
      blue = Geom::Vector3d.new(0,0,1) 
      
      # determine  the basic orientation
      return nil if not (axis = longest_edge(timber))  #CI has no edges?
      lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector
      lev.transform!(timber.transformation)
      
      # determine it's got a 'rafter' configuration, and if so, rotate "down" forst, then apply direction labels
      # z == 0 means horizontal (girt)  z==1 means vertical (post)  Anything else is "rafter-like"
      if lev.z.abs > 0.00001 and lev.z.abs < 0.999999 then
        #print("Rafter.  lev: \t"+lev.to_s+"\n")
        if lev.x.abs < 0.00001
          # rafter in the green-blue plane  
          #print("green-blue rafter\n")
          rotate_around_axis(timber, red, green)
          #UI.messagebox("pause after red rotatation toward green")
          if make_dir_lables then
            add_directional_lables(timber)
          end      
          rotate_around_axis(timber, blue, red)
          #UI.messagebox("pause after blue rotatation toward red")
          roll_plumb(timber)
        elsif lev.y.abs < 0.00001 
          #rafter in the red-blue plane
          #print("red-blue rafter\n")
          rotate_around_axis(timber, green, red)
          if make_dir_lables then
            add_directional_lables(timber)
          end      
          rotate_around_axis(timber, blue, red)  # redundnat?
          roll_plumb(timber)
        else
          # valley rafter? don't bother with direction labels.
          #print("valley rafter\n")
          rotate_around_axis(timber, green, red)
          rotate_around_axis(timber, blue, red)  
          roll_plumb(timber)
        end
      else # not a rafter
        #print("not a rafter\n")
        roll_plumb(timber)
        if make_dir_lables then
          add_directional_lables(timber)
        end      
        rotate_around_axis(timber, green, red)
        rotate_around_axis(timber, blue, red)
        #UI.messagebox("pause3")
      end
    end  # lay down on red

    def largest_face(timber)
      cd = timber.definition
      largest = nil
      cd.entities.each do |e|
        next if not e.instance_of? Sketchup::Face
        if (largest == nil) or (e.area > largest.area)
          largest = e
        end
      end
      return largest
    end

    def longest_edge(timber)
      cd = timber.definition
      longest = nil
      cd.entities.each do |e|
        next if not e.instance_of? Sketchup::Edge
        if (longest == nil) or (e.length > longest.length)
          longest = e
        end
      end
      return longest
    end

    def rotate_around_axis(timber, rot_axis, target_axis)
      # rotate around rot_axis so that we lie in the plane of rot_axis and target_axis
      #print("rot_axis: "+rot_axis.to_s+"\n")
      #print("target_axis: "+target_axis.to_s+"\n")

      rp = Geom::Point3d.new(0,0,0)     #rotation point
      # translate this point to global coordinates    
      rp.transform!(timber.transformation)        
      
      return nil if not (axis = longest_edge(timber))  #CI has no edges?
      lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector
      # print("lev b4: " + lev.to_s + "\n")
      # translate this to global coordinates
      lev.transform!(timber.transformation)
      #print("lev xfromed: " + lev.to_s + "\n")
      test_lev = Geom::Vector3d.new(lev)
      
      proj = Geom::Vector3d.new(0,0,0)  # projection of lev onto plane of rotation.  Used to compute the rotation angle
      
      #av.set!(lev.x, 0, lev.z)
      if rot_axis.x == 1 
      then proj.x=0 
      else proj.x=lev.x
      end  
      if rot_axis.y == 1 
      then proj.y = 0
      else proj.y = lev.y
      end
      if rot_axis.z == 1
      then proj.z = 0
      else proj.z = lev.z
      end  
      #print("proj: "+proj.to_s+"\n")
      return if proj.length.abs < 0.00001
      
      rot_ang = proj.angle_between(target_axis)
      #print("prelim rotation: " + rot_ang.radians.to_s + "\n")
      return if rot_ang.abs < 0.00001

      rt = Geom::Transformation.rotation(rp, rot_axis, rot_ang) # rotation transform
      proj.transform!(rt)   
      # proj should now be on top of the desination vector
      # if not, its becaue of a sketchup peculiarity with the angle_between function, which will not
      # return a negative value.  If not, reverse the angle
      #print("proj (after test rotate): "+proj.to_s+"\n")
      unless proj.angle_between(target_axis).abs < 0.00001
        rot_ang = -rot_ang
        #print("reversing rotation\n")
      end      

      # take the shortest rotation path to the target, so the top of a rafter stays on top
      if rot_ang.abs > 90.degrees then
        rot_ang -= 180.degrees
        if rot_ang < 180.degrees 
          rot_ang += 360.degrees
        end  
      end
      
      rt = Geom::Transformation.rotation(rp, rot_axis, rot_ang) 
      #print("rotation: " + rot_ang.radians.to_s + "\n")
      timber.transform!(rt)
    end

    def roll_plumb(timber)
      
      blue = Geom::Vector3d.new(0,0,1) 

      # is the largest face neither plumb nor level?
      return nil if not (lf = largest_face(timber)) #CI has no faces?
      lfv = lf.normal
      lfv.transform!(timber.transformation)
      ra = lfv.angle_between(blue)   #rotation angle
      #print("rotation angle: " + ra.radians.to_s + "\n")

      # if we're already plumb or level, then bail out
      return if (ra.abs <= 0.0001)
      return if (ra.abs - 180.degrees).abs <= 0.0001 
      return if (ra.abs - 90.degrees).abs <= 0.0001 
      
      #print("Cockeyed\n") 
      # roll to the nearest plumb or level plane
      if ra > 45.degrees and ra < 135.degrees
        ra-=90.degrees
      elsif ra > 135.degrees and ra < 225.degrees
        ra -= 180.degrees
      elsif ra > 225.degrees and ra < 315.degrees
        ra -= 270.degrees
      elsif ra > 315.degrees and ra < 360.degrees
        ra -= 360.degrees
      end
      
      return nil if not (axis = longest_edge(timber))  #CI has no edges?
      lev = Geom::Vector3d.new(axis.line[1])  # longest edge vector  
      lev.transform!(timber.transformation)
      
      rv = Geom::Vector3d.new(lev) # rotation vector (rotate around lev)
      rp = Geom::Point3d.new(0,0,0)     #rotation point
      # translate this point to global coordinates    
      rp.transform!(timber.transformation)        
      rt = Geom::Transformation.rotation(rp, rv, ra) 
      lfv.transform!(rt)   
      #print("lfv1:" + lfv.to_s + "\n")
      # lfv should now be plumb or level
      # if not, its becaue of a sketchup peculiarity with the angle_between function, which will not
      # return a negative value.  So the lfv z value should be 1 or zero.  If not, reverse the angle
      unless (lfv.z.abs >= 0.9999) or (lfv.z.abs <=0.00001)
        ra = -ra
        #print("reversing plumb rotation\n")
      end        

      #print("plumb rotation: " + ra.radians.to_s + "\n")
      rt = Geom::Transformation.rotation(rp, rv, ra) 
      timber.transform!(rt)
    end

    def get_dimensions(timber, min_len, metric, roundup, tdims)
      model = Sketchup.active_model
      grp = model.entities.add_group
      clone = grp.entities.add_instance(timber.definition, timber.transformation) 
      clone.make_unique
      lay_down_on_red(clone)
      subcomp = Array.new
      clone.definition.entities.each do |s|
        if s.instance_of? Sketchup::ComponentInstance then 
          subcomp.push(s)
        end
      end  
      subcomp.each do |sc|
        sc.explode
      end
      clone.explode
      cps = Array.new
      grp.entities.each do |cp|
        if cp.instance_of? Sketchup::ConstructionPoint
          #print("contruction point found, pushing\n")
          cps.push cp
        end  
      end
      cps.each do |cp|
        #print("erasing cp\n")
        cp.erase!
      end
      tdims.clear
      if metric then
        tdims.push grp.bounds.width.to_feet.to_mm
        tdims.push grp.bounds.depth.to_feet.to_mm
        tdims.push grp.bounds.height.to_feet.to_mm
      else
        tdims.push grp.bounds.width.to_feet
        tdims.push grp.bounds.depth.to_feet
        tdims.push grp.bounds.height.to_feet
      end  
      tdims.each_index do |i|
        tdims[i]=tdims[i]*1000
        tdims[i]=tdims[i].round
        tdims[i]=tdims[i]/1000.to_feet
      end
      if roundup 
        tdims.each_index do |i|
          tdims[i]= tdims[i].ceil
        end
      end
      tdims.sort!
      #UI.messagebox("pause for dims")
      grp.erase!
      if metric
      then tdims[3] =  tdims[2] #((tdims[2] + min_len + 100)/100).floor
      else tdims[3] =  2*(((tdims[2] + min_len + 24)/24).floor)
      end
    end

  def verticies_in_bbox(timber=nil, bbox=nil)
      count = 0
      if timber != nil && bbox != nil && bbox.valid?
        v = []
        entities(timber).each { |e|
          if e.is_a?(Sketchup::Edge)
            v.concat(e.vertices)
          elsif e.is_a?(Sketchup::Face)
            e.edges.each { |edg| v.concat(edg.vertices) }
          end
        }
        v.uniq!
        v.each { |vert|
          gpos = vert.position.transform timber.transformation
          # print("\t", gpos.to_s, "\n")
          if bbox.contains?(gpos)
            count += 1
          end
        }
      end
      return count
    end
    
    def intersecting_group(e1=nil, e2=nil)
      if e1.is_a?(Sketchup::Group) || e1.is_a?(Sketchup::ComponentInstance)
        es1 = entities(e1)
        fail = false
      else
        fail = true
      end
      if e2.is_a?(Sketchup::Group) || e2.is_a?(Sketchup::ComponentInstance)
        fail = false
      else
        fail = true
      end
      if fail
         puts("#{self}.intersect? requires references to two groups/component-instances.\nReturns 'true' [intersecting || touching] or 'false'.")
         return nil
      end

      ens = e1.parent.entities
      tr1 = e1.transformation
      grp = ens.add_group()
      grp.transform!(tr1) ### so can see cut lines IF erase! is disabled at the end !
      ges = grp.entities
      es1.intersect_with(true, tr1, ges, tr1, true, e2)

      if ges[0]
        g = grp
      else
        g = nil
      end
      grp.erase!
      return g
    end
    
    def intersecting_solids(primary, entities)
      ents = []
      entities.each { |e|
        # ents.push e if e != primary && EneSolidTools::Solids.is_solid?(e) && intersect?(@primary, e)
        ents.push(e) if e != primary && e.manifold? && intersect?(@primary, e)
      }
      return ents
    end
    
    def intersect?(e1=nil, e2=nil)
      if e1.is_a?(Sketchup::Group) || e1.is_a?(Sketchup::ComponentInstance)
        es1 = entities(e1)
        fail = false
      else
        fail = true
      end
      if e2.is_a?(Sketchup::Group) || e2.is_a?(Sketchup::ComponentInstance)
        fail = false
      else
        fail = true
      end
      if fail
        puts("#{self}.intersect? requires references to two groups/component-instances.\nReturns 'true' [intersecting || touching] or 'false'.")
         return nil
      end

      ens = e1.parent.entities
      tr1 = e1.transformation
      grp = ens.add_group()
      grp.transform!(tr1) ### so can see cut lines IF erase! is disabled at the end !
      ges = grp.entities
      es1.intersect_with(true, tr1, ges, tr1, true, e2)

      if ges[0]
         int = true
      else
         int = false
      end
      grp.erase!
      return int
    end

  end # class SolidsMakeShopDrawingTool

end # module KLP::Plugins::SolidsMakeShopDrawing
  
