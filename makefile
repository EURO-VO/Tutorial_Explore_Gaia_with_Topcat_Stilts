
#####################################################################
# Configuration

# Name of the tutorial document.
DOC = tctuto

# Must point to a PDFLATEX command.
PDFLATEX = pdflatex

# This lists data files which can be built by this makefile, and which
# contain copies of the tables that are generated by user actions
# (querying remote services and performing local operations) during
# the tutorial.  You don't have to build these, but if you do, then
# it's still possible to run much of the tutorial with no network access.
DATA = m4.fits hy.fits ngc346.fits ngc346-gaia.fits ngc346xDR2.fits \
       hrd-100pc.fits hrd-66pc.fits \
       hrd.fits hrd_clean.fits \

# Name of repository.  Only used to annotate the generated document,
# alongside the git commit date and SHA1.
REPO = https://github.com/mbtaylor/tctuto

# The stilts command required to generate the data.
# This tutorial was developed with STILTS v3.1-5; later versions should
# probably work, but if you suspect there's a version issue, you could
# try getting a the relevant version from the old version archive at
# ftp://andromeda.star.bris.ac.uk/pub/star/stilts/ or maybe github.
# If you don't have a stilts script on the path, you can replace this with
# STILTS = ./stilts.
STILTS = stilts

#####################################################################
# Useful targets

build: $(DOC).pdf

view: $(DOC).view

data: $(DATA)

clean:
	rm -f $(DOC:=.aux) $(DOC:=.log) $(DOC:=.out) $(DOC:=.pdf) \
              $(DOC:=.toc) version.tex

cleandata:
	rm -f $(DATA)

cleanstilts:
	rm -f ./stilts stilts.jar

veryclean: clean cleandata cleanstilts


#####################################################################
# Internals

.SUFFIXES: .tex .pdf .view

$(DOC).pdf: $(DOC).tex
	git show -s --format='{%cd \ \ Revision {\tt %h ($(REPO))}}' \
                    --date=short \
            >version.tex
	$(PDFLATEX) $< && \
        $(PDFLATEX) $< || \
        rm -f $@

.pdf.view:
	test -f $< && acroread -geometry +50+50 -openInNewWindow $<

./stilts: stilts.jar
	unzip stilts.jar stilts
	chmod +x $@

stilts.jar:
	curl -L http://www.starlink.ac.uk/stilts/stilts.jar >$@

m4.fits:
	$(STILTS) tpipe in='http://gaia.ari.uni-heidelberg.de/cone/search?RA=245.89675&DEC=-26.52575&SR=0.3&VERB=2' \
               out=$@

hy.fits:
	$(STILTS) tapquery \
            sync=true \
            tapurl=http://gea.esac.esa.int/tap-server/tap \
            adql="SELECT ra, dec, pmra, pmdec, parallax, radial_velocity, \
                         phot_g_mean_mag, bp_rp \
                  FROM gaiadr2.gaia_source \
                  WHERE parallax > 15 \
                  AND parallax_over_error > 5 \
                  AND radial_velocity IS NOT NULL" \
            out=$@

ngc346.fits:
	$(STILTS) tpipe \
               in='http://vizier.u-strasbg.fr/viz-bin/votable?-source=J%2fApJS%2f166%2f549&-oc.form=dec&-out.meta=DhuL&-c=14.771207+-72.1759&-c.rd=1.0&-out.add=_RAJ%2C_DEJ%2C_r&-out.max=100000' \
               out=$@

ngc346-gaia.fits:
	$(STILTS) tpipe in='http://gaia.ari.uni-heidelberg.de/cone/search?RA=14.771207&DEC=-72.1759&SR=0.05&VERB=1' \
               out=$@

ngc346xDR2.fits: ngc346.fits
	$(STILTS) cdsskymatch \
               cdstable='GAIA DR2' find=all \
               in=ngc346.fits ra=_RAJ2000 dec=_DEJ2000 radius=1 \
               out=$@

hrd-100pc.fits:
	$(STILTS) tapquery \
            sync=false \
            tapurl=http://gea.esac.esa.int/tap-server/tap \
            adql="SELECT ra, dec, parallax, phot_g_mean_mag, bp_rp, \
                         phot_g_mean_mag + 5*log10(parallax/100) as mg, \
                         astrometric_excess_noise, \
                         phot_bp_rp_excess_factor \
                  FROM gaiadr2.gaia_source \
                  WHERE parallax > 10 \
                    AND parallax_over_error > 10 \
                    AND phot_bp_mean_flux_over_error > 10 \
                    AND phot_rp_mean_flux_over_error > 10" \
            out=$@

hrd-66pc.fits:
	$(STILTS) tapquery \
            sync=false \
            tapurl=http://gea.esac.esa.int/tap-server/tap \
            adql="SELECT ra, dec, parallax, phot_g_mean_mag, bp_rp, \
                         phot_g_mean_mag + 5*log10(parallax/100) as mg, \
                         astrometric_excess_noise, \
                         phot_bp_rp_excess_factor \
                  FROM gaiadr2.gaia_source \
                  WHERE parallax > 15 \
                    AND parallax_over_error > 10 \
                    AND phot_bp_mean_flux_over_error > 10 \
                    AND phot_rp_mean_flux_over_error > 10" \
            out=$@

hrd.fits: hrd-100pc.fits
	ln -s hrd-100pc.fits $@

hrd_clean.fits: hrd.fits
	stilts tpipe \
               in=hrd.fits \
               cmd='addcol g_abs "phot_g_mean_mag + 5*log10(parallax/100)"' \
               cmd='select "astrometric_excess_noise < 1"' \
               cmd='select "phot_bp_rp_excess_factor < \
                            polyLine(bp_rp, -0.56,1.307, 0.03,1.192, \
                                            1.51,1.295, 4.31,1.808)"' \
               out=$@

figures/hrd_only.png: hrd_clean.fits
	stilts plot2plane \
               insets=-4,-4,-4,-4 minor=false xpix=600 ypix=500 yflip=true \
               densemap=heat denseclip=0.07,1 \
               layer1=mark in1=hrd_clean.fits x1=bp_rp y1=mg shading1=density \
               out=$@

