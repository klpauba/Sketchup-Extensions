# coding: utf-8
#-------------------------------------------------------------------------------
#
# Kevin L. Pauba
# klpauba[at]gmail[dot]com
#
# This extension will generate a shop drawing for the selected Timber Frame component (which must be a solid).
# It will identify other intersecting solids and automatically "trim" these solids with the selected
# component (thus creating mortises and peg holes in the drawings). The shop drawing will be automatically saved
# in a separate Sketchup file and the current drawing remains unchanged.
#
# This extension is possible due to the incredible work by other authors:
#
# Thomas Thomassen -- thomas[at]thomthom[dot]net
#    * SolidInspector2: Inspect and fix problems with geometry that should be manifold (solids).
#    * Many other librarys (TT_Libs, etc.)
#
# Julia Christina Eneroth -- eneroth3[at]gmail.com
#    * Eneroth solid Tools: Performs the same operations as the Sketchup Solid Tools but multiple
#      secondary solids can be selected that operate on the primary solid.  It will keep its layer,
#      material, attributes and ruby variables.  If the primary is a component, all will be changed.
#
# daiku
#    * Timber Framing Extensions: automate the creation of mortise and tenon joints, generate
#      shop drawings, create timebr material lists, and help you create presentation drawings.
#
#-------------------------------------------------------------------------------

require "sketchup.rb"
require "extensions.rb"

#-------------------------------------------------------------------------------

module KLP
 module Plugins
  module SolidsMakeShopDrawing

  ### CONSTANTS ### ------------------------------------------------------------

  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = "KLP_SolidsMakeShopDrawing".freeze
  PLUGIN_NAME     = "Solids Make Shop Drawing".freeze
  PLUGIN_VERSION  = "1.0.0".freeze

  # Resource paths
  file = __FILE__.dup
  file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
  FILENAMESPACE = File.basename(file, ".*")
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, FILENAMESPACE).freeze


  ### EXTENSION ### ------------------------------------------------------------

  unless file_loaded?(__FILE__)
    loader = File.join(PATH, "bootstrap.rb")
    @extension = SketchupExtension.new(PLUGIN_NAME, loader)
    @extension.description = "Create Shop Drawing for a Timber Frame Component that is a Sketchup Solid"
    @extension.version     = PLUGIN_VERSION
    @extension.copyright   = "Kevin L. Pauba © 2017"
    @extension.creator     = "Kevin L. Pauba (klpauba@gmail.com)"
    Sketchup.register_extension(@extension, true)
  end

  end # module SolidsMakeShopDrawing
 end # module Plugins
end # module KLP

#-------------------------------------------------------------------------------

file_loaded(__FILE__)

#-------------------------------------------------------------------------------
