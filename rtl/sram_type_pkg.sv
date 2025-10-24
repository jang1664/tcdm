package sram_type_pkg;

  // Technology selection
  typedef enum logic {
    TECH_FDSOI = 1'b0,
    TECH_LPP   = 1'b1
  } tech_e;

  // Memory type 1 selection
  typedef enum logic {
    TYPE1_RA = 1'b0,  // Read Assist
    TYPE1_RS = 1'b1   // Read Static
  } type1_e;

  // Memory type 2 selection  
  typedef enum logic {
    TYPE2_HD = 1'b0,  // High Density
    TYPE2_HS = 1'b1   // High Speed
  } type2_e;

  // Threshold voltage selection
  typedef enum logic {
    VTH_L = 1'b0,     // Low Vth
    VTH_R = 1'b1      // Regular Vth
  } vth_e;

  // Write mask enable
  typedef enum logic {
    WMASK_DISABLE = 1'b0,
    WMASK_ENABLE  = 1'b1
  } wmask_e;

endpackage
