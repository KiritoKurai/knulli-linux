################################################################################
#
# knulli-atm7039-fixes
#
# Ajustos de build específics per a l'Anbernic RG35XX original (ATM7039).
# No és un paquet: només sobreescriu variables d'altres paquets quan el
# target és atm7039.
#
################################################################################

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_ATM7039),y)

# python-evdev genera les seves taules de codis a partir de les capçaleres
# del kernel. El kernel de l'RG35XX és 3.10 i no té
# linux/input-event-codes.h (aparegut al 4.4); tots els codis són a
# linux/input.h. Sense aquest canvi el build de python-evdev falla, i
# aquest paquet és imprescindible (configgen, evmapy, hotkeygen).
PYTHON_EVDEV_BUILD_OPTS = \
	-C--build-option=build_ecodes \
	-C--build-option=--evdev-headers=$(STAGING_DIR)/usr/include/linux/input.h:$(STAGING_DIR)/usr/include/linux/uinput.h

endif
