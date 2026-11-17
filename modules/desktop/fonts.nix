{pkgs, ...}: {
  fonts = {
    fontconfig = {
      defaultFonts = {
        monospace = [
          "Iosevka Nerd Font"
          "JetBrainsMono Nerd Font"
        ];
        sansSerif = ["Public Sans"];
        serif = ["Noto Serif"];
        emoji = ["Noto Color Emoji"];
      };
    };

    packages = with pkgs; [
      nerd-fonts.iosevka

      noto-fonts
      public-sans

      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only

      noto-fonts-color-emoji
      comic-relief
      corefonts
      # The Office/Vista set Word and PowerPoint default to (Calibri,
      # Cambria, Candara, Consolas, Corbel, Constantia). Without it those
      # names fall back to Public Sans / Noto Serif and documents reflow.
      vista-fonts
      # Metric-compatible stand-ins for the Windows fonts documents often
      # ask for, so line breaks and page counts stay the same when the real
      # font isn't installed: Carlito→Calibri, Caladea→Cambria,
      # Times Newer Roman→Times New Roman, Liberation Sans Narrow→Arial Narrow.
      carlito
      caladea
      times-newer-roman
      liberation-sans-narrow
      # The whole Google Fonts library, so Canva/Word designs that name a
      # font by hand (Montserrat, Poppins, Oswald, …) render instead of
      # silently falling back.
      google-fonts
      # Arabic faces for Office documents: Amiri is the Naskh classic,
      # Scheherazade is what SIL/LaTeX use, and KACST ships on Arabic Windows.
      amiri
      scheherazade-new
      kacst

      fira
      fira-code
      fira-code-symbols
      cascadia-code
      source-sans
      source-serif
      source-code-pro
      inter
      roboto
      roboto-mono
      roboto-slab
      lato
      ubuntu-classic
      ubuntu-sans
      ubuntu-sans-mono
      liberation_ttf
      freefont_ttf
      proggyfonts
      cantarell-fonts
      dejavu_fonts
      gyre-fonts
      font-awesome
      material-icons
      material-design-icons

      # Microsoft Aptos (Bierstadt), the Office default that replaced
      # Calibri. Microsoft offers it free for local installation, so fetch
      # the official zip rather than relying on the Office Font Service.
      (pkgs.stdenv.mkDerivation {
        pname = "aptos-fonts";
        version = "4.40";

        src = pkgs.fetchurl {
          url = "https://download.microsoft.com/download/8/6/0/860a94fa-7feb-44ef-ac79-c072d9113d69/Microsoft%20Aptos%20Fonts.zip";
          hash = "sha256-ZSj9Eg5xmp+YXpQhTspoh9FlO4hFaRankqYwsC6VsCU=";
        };

        nativeBuildInputs = [pkgs.unzip];

        # The zip holds flat .ttf files, so there is no source tree to unpack.
        unpackPhase = "true";

        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/fonts/truetype/aptos
          unzip -q "$src" '*.ttf' -d $out/share/fonts/truetype/aptos
          runHook postInstall
        '';
      })

      (pkgs.stdenv.mkDerivation {
        name = "century-schoolbook";
        src = ../../assets/fonts;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp *.TTF $out/share/fonts/truetype/
        '';
      })
    ];
  };
}
