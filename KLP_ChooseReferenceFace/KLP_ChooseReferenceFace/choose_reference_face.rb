##
##  choose_reference_face.rb
##
##	Copyright (C) 2016 Kevin L. Pauba
##	klpauba@gmail.com
##
##  	This extension allows you to identify the selected edge and
##  	faces as the arris and reference face of a timber.  This
##  	extension is useful in timberframing.
##
##      While in a component, double click on any edge to select the
##      edge and the two connected faces.  The selected edge becomes
##      the arris.  Now, move the cursor over one of the two faces and
##      it will be outlined in red.  You identify the reference face
##      by clicking the left mouse button while your choice of the two
##      faces is outlined.  A reference mark (a closed triangle) will
##      be drawn on the reference face pointing to the arris at a
##      location determined by the cursor position.  Another mark (an
##      open triangle) will be drawn on the adjacent face pointing to
##      the same location on the arris.
##
##      You can click the left mouse button repeatedly to move the
##      reference marks or change the reference face.  The tool
##      remains active until another tool is chosen.  If necessary,
##      you can Undo any and each mark.
##
##      Each reference mark is drawn as a separate group and are
##      placed on their own layer named "Reference Marks".
##

require 'sketchup.rb'

module KLP_CRF
  REFERENCE_MARK_LAYER_NAME = "Reference Marks"

  # Return the selected arris (edge) if, and only if, an arris and two
  # connected faces are selected in a component definition
  def KLP_CRF.selected_arris
    mm = Sketchup.active_model
    ss = mm.selection

    ecount = 0
    fcount = 0
    arris = nil
    ss.each do |ee|
      if ee.instance_of? Sketchup::Edge
        if ee.parent.instance_of? Sketchup::ComponentDefinition
          arris = ee
          ecount += 1
        end
      elsif ee.instance_of? Sketchup::Face
        fcount += 1
      end
    end
    return arris if ecount == 1 && fcount == 2
    return nil
  end

  # Enable the menu item if the arris and two connected faces are
  # selected
  def KLP_CRF.arris_valid_proc
    return MF_ENABLED if KLP_CRF.selected_arris
    return MF_GRAYED
  end
  
  class ChooseReferenceFaceTool

    # Called when class is loaded
    def initialize
      @cursor_point = nil
      # @ref_cursor = getCursorID("ref.pdf",0,0)
      @best = nil
      @face = nil
      @loop = nil
    end
    
    # Called when this tool is chosen
    def activate
      @cursor_point	  = Sketchup::InputPoint.new

      @arris = KLP_CRF.selected_arris
      @model = Sketchup.active_model
      
      @drawn = false
      
      self.reset(nil)
      Sketchup.set_status_text("Choose the reference face")
    end
    
    # Called when another tool is chosen
    def deactivate(view)
      view.invalidate if @drawn
    end
    
    # Reset the tool back to its initial state
    def reset(view)
      if view
        view.tooltip = nil
        view.invalidate if @drawn
      end

      @drawn = false
    end
    
    # Called when the mouse moves while the tool is active
    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      
      @face = ph.picked_face if ph.picked_face != @face
      @best = ph.best_picked if ph.best_picked != @best
      
      @cursor_point.pick(view, x, y)
      @cursor_point.draw(view)
      view.invalidate
    end
    
    # Called when the left mouse button is released
    def onLButtonUp(flags, x, y, view)
      if @face && @arris.faces.include?(@face)
        #
        # Determine the point on the @arris where the marks will be
        # drawn.
        #
        ip = view.inputpoint x,y
        arris_point = ip.position.project_to_line @arris.line


        @model.start_operation("Add reference marks", true) 

        ent = @arris.parent.entities
        ent.each { |e|
    	  next if not e.instance_of? Sketchup::Group
          ent.erase_entities(e) if e.name == 'RefMark' || e.name == 'AdjMark'
        }

        # Draw the reference marks on the arris (nearest the cursor) with the
        # selected @face as the reference face other face as the adjacent face
        refgrp = ent.add_group()
        refgrp.name = 'RefMark'
        adjgrp = ent.add_group()
        adjgrp.name = 'AdjMark'
        
        hyp = Math.sqrt(3)
        p0 = [0, 0, 0.001]		# z-coordinate will put mark just above face
        p1 = [1.0, hyp, 0.001]
        p2 = [-1.0, hyp, 0.001]

        #
        #    1) Find the normal vector to the face (@face.normal). This will be
        #       the z-axis for a later transformation.
        #    2) Find the perpendicular vector that is coincident with the edge
        #       (edge.line[1]).  This will be the x-axis for a later transformation.
        #    3) Find an orthogonal vector to the previous two vectors using
        #       Vector3d.cross (cross product).  This will be the y-axis for
        #       a later transformation.
        #    4) Reverse the y-axis if the edge traverses the face in the
        #       reverse direction.
        #    4) Create a new transform with the arris_point (Point3d) as the
        #       origin and the three vectors for the axes.
        #
        mark = refgrp.entities.add_face(p0,p1,p2)
        mark.material = 'black'
        mark.back_material = 'black'
        z = @face.normal
        x = @arris.line[1]
        y = z.cross x
        y.reverse! if @arris.reversed_in? @face
        t = Geom::Transformation.new(x, y, z, arris_point)
        refgrp = refgrp.transform! t
        
        mark = adjgrp.entities.add_face(p0,p1,p2)
        mark.material = 'white'
        mark.back_material = 'white'
        adjface = (@face == @arris.faces[0] ? @arris.faces[1] : @arris.faces[0])
        z = adjface.normal
        x = @arris.line[1]
        y = z.cross x
        y.reverse! if @arris.reversed_in? adjface
        t = Geom::Transformation.new(x, y, z, arris_point)
        adjgrp = adjgrp.transform! t

        #
        # Add the marks to their own special layer
        #
        mark_layer = @model.layers.add REFERENCE_MARK_LAYER_NAME
        refgrp.layer = adjgrp.layer = mark_layer

	#
	# Now calculate the section modulus (assume the timber is
	# rectangular in cross-section and homogeneous so that the
	# neutral axis passes through the center of the timber).
        #
        # NOTE: What about braces, rafters, struts, etc.?
        #
	# 1) Choose one of the two marked faces whose normal is
	#    perpendicular to the ground plane (in world coordinates).
	#    This tells us which dimension will be the height and
	#    which is the depth.  2) Find one edge that is not the
	#    same length of the arris.  This must be one edge of the
	#    end of the timber and the length of the chosen edge
	#    represents 'b' (the breadth of the beam).
        #
        # --- OR ---
        #
        # 2) Choose either vertex of the arris and then find the lines
        #    that share this common vertex (there will be 3).  The two
        #    edges that are not the arris represent the 'h' (the
        #    height) and 'b' (the breadth) of the beam.  if one of the
        #    edges defines the perpendicular face that is common with
        #    the arris, that edge is 'b'.
        #
	# 3) Find all edges that bound the face.  
	# 4) Find and edge that is not the same length as 'b'.  If one is found,
	#    it represents 'h' (the height of the beam).  Otherwise, the beam
	#    must be square and 'h' is the same as 'b'.
	# 4) Calculate the geometric properties of the rectangle:

        #      a) Elastic Section Modulus: S = b*h^2/6
        #      d) Moment of inertia about the center axis:    I(xc)=b*h^3/12=S*h/2, I(yc)=b^3*h/12=S*b/2, I(zc)=b*h*(b^2+h^2)/12
        #      e) Radius of gyration about the center axis:   k(xc)=h/(2*sqrt(3)),k(yc)=b/(2*sqrt(3)), k(zc)=sqrt(b^2+h^2)/(2*sqrt(3))
        #      b) Moment of inertia about x-,y- and z-axis:   I(x)=4*I(xc), I(y) = 4*I(yc), I(z) = 4*I(zc)
        #      c) Radius of gyration abount x-,y- and z-axis: k(x)=2*k(xc), k(y)=2*k(yc), k(z)=2*k(zc)
        #
	# 5) Save the calculated Section Modulus as an attribute of the timber.
	#
        v = @arris.start
        e = v.edges
        e.delete(@arris)
        print "Arris: ", @arris, "\n"
        print "Edges: ", e, "\n"
        sm = [0.0, 0.0]
        l = [0.0, 0.0]
        if e[0].common_face(@arris) == @face
          l[0] = e[0].length
          l[1] = e[1].length
        else
          l[0] = e[1].length
          l[1] = e[0].length
        end
        sm[0] = l[0] * l[1] ** 2 / 6
        sm[1] = l[1] * l[0] ** 2 / 6
        print "Geometric Properties (S, I & k about center axes)\n"
        print "================================================================\n"
        print "Arris Length (A): ", @arris.length, "\n"
        print "End Dimenstions (L): ", l, " inches\n"
        print "Section Modulus (S): ", sm, " inches^3\n"
        print "Moment of Inertia (I): [", sm[0]*l[1]/2, ", ", sm[1]*l[0]/2, "] inches^4\n"
        print "Radius of Gyration (k): [", l[1]/(2*Math.sqrt(3)), ", ", l[0]/(2*Math.sqrt(3)), ", ", Math.sqrt(l[0]**2+l[1]**2)/(2*Math.sqrt(3)), "] inches\n"

        @model.commit_operation
      end
    end

    def draw(view)
      if @face && @best.is_a?(Sketchup::Face) && @arris.faces.include?(@face)
        @face.loops.each { |loop|
          loop.edges.each { |e| draw_edge(view, e) }
        }
        @drawn = true
      end
    end
    
    def draw_edge(view, edge, drawing_color='red')
      p1 = edge.start.position
      p2 = edge.end.position
      
      view.line_width = 5.0
      view.drawing_color = drawing_color
      view.draw_line(p1, p2)
    end
    
  end # class

### menu
this_file=File.basename(__FILE__)
unless file_loaded?(this_file)
  UI.add_context_menu_handler do |menu|
    if menu == nil then
      UI.messagebox("Error setting context menu handler!")
      return
    end
    crf_menu_item = menu.add_item("Choose Reference Face") {Sketchup.active_model.select_tool(ChooseReferenceFaceTool.new)}
    menu.set_validation_proc(crf_menu_item) {KLP_CRF.arris_valid_proc}
  end
  file_loaded(this_file)
  print "CRF Loaded!"
end
  
end # module

