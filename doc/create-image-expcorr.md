Create Exposure-Corrected Images
================================

1. Data reduction and create a basic manifest file (will be used by
   subsequent tools):

   ```sh
   $ cd <obsid>
   $ repro_acis.py
   ```

2. Clean the level=2 event file by removing point sources and flares:

   ```sh
   $ mkdir evt && cd evt
   $ ln -s ../repro/*_repro_evt2.fits .
   $ clean_evt2.py
   $ cd ..
   ```

3. Get image grids (``xygrid`` output from ``get_fov_limits``):

   ```sh
   $ mkdir img && cd img
   $ get_fov_limits "../repro/*_repro_fov1.fits[ccd_id=0:3]"  # ACIS-I
   $ get_fov_limits "../repro/*_repro_fov1.fits[ccd_id=7]"  # ACIS-S
   ```
