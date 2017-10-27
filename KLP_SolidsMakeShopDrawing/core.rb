#-------------------------------------------------------------------------------
#
# Kevin L. Pauba
# klpauba[at]gmail[dot]com
#
#-------------------------------------------------------------------------------


module KLP::Plugins::SolidsMakeShopDrawing

  # require File.join(PATH, "debug_tools.rb")
  require File.join(PATH, "solids_make_drawing_tool.rb")
  require File.join(PATH, "settings.rb")


  # PATH_IMAGES  = File.join(PATH, "images").freeze
  # PATH_GL_TEXT = File.join(PATH_IMAGES, "text").freeze
  # PATH_HTML    = File.join(PATH, "html").freeze


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?(__FILE__)
    # cmd = UI::Command.new(PLUGIN_NAME) {
    #   self.solids_make_shop_drawing
    # }
    # cmd.tooltip = "Create Timber Frame shop drawing of selected solid groups and component."
    # cmd.status_bar_text = "Create Timber Frame shop drawing of selected solid groups and components."
    # # cmd.small_icon = File.join(PATH_IMAGES, 'Inspector-16.png')
    # # cmd.large_icon = File.join(PATH_IMAGES, 'Inspector-24.png')
    # cmd_make_drawing = cmd

    # menu = UI.menu("Extensions")
    # menu.add_item(cmd_make_drawing)

    # if Settings.debug_mode?
    #   debug_menu = menu.add_submenu("#{PLUGIN_NAME} Debug Tools")

    #   # debug_menu.add_item("Debug Reversed Faces") {
    #   #   Sketchup.active_model.select_tool(DebugFaceReversedTool.new)
    #   # }
    # end

    # # toolbar = UI.toolbar(PLUGIN_NAME)
    # # toolbar.add_item(cmd_make_drawing)
    # # toolbar.restore

    UI.add_context_menu_handler do |menu|
      if menu == nil then
        UI.messagebox("Error setting context menu handler!")
        return
      end
      crf_menu_item = menu.add_item("Solids Make Shop Drawing") {self.solids_make_shop_drawing}
      menu.set_validation_proc(crf_menu_item) {self.is_solid_selected}
    end

    file_loaded(__FILE__)
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  def self.solids_make_shop_drawing
    Sketchup.active_model.select_tool(SolidsMakeShopDrawingTool.new)
  # rescue Exception => error
  #   ERROR_REPORTER.handle(error)
  end


  ### DEBUG ### ----------------------------------------------------------------

  def self.is_solid_selected
    mm = Sketchup.active_model
    ss = mm.selection
    if ss.size == 1 && ss[0].is_a?(Sketchup::ComponentInstance || Sketchup::Group) && ss[0].manifold?
      return MF_ENABLED
    else
      return MF_GRAYED
    end
  end
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   KLP::Plugins::SolidsMakeShopDrawing.reload
  #
  # @return [Integer] Number of files reloaded.
  # noinspection RubyGlobalVariableNamingConvention
  def self.reload()
    original_verbose = $VERBOSE
    $VERBOSE = nil
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?(PATH) && File.exist?(PATH)
      x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module
