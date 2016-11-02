 # Register and Load CRF extension
 require 'sketchup.rb'
 require 'extensions.rb'

 klp_extension = SketchupExtension.new("Choose Reference Face", "KLP_ChooseReferenceFace/choose_reference_face.rb")
 klp_extension.version = '1.0.0'
 klp_extension.description = "Select and edge as the arris and choose the referenence face."
 klp_extension.copyright = "Copyright (c) 2016, Kevin L. Pauba"
 klp_extension.creator = "Kevin L. Pauba"
 Sketchup.register_extension(klp_extension, true)
