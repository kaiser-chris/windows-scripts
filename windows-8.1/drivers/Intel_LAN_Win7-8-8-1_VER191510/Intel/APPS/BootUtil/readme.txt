Intel(R) Master FLB file format change
======================================

March 6, 2012


DISCLAIMER
==========

This software is furnished under license and may only be used or copied
in accordance with the terms of the license.  The information in this
manual is furnished for informational use only, is subject to change
without notice, and should not be construed as a commitment by Intel
Corporation.  Intel Corporation assumes no responsibility or liability
for any errors or inaccuracies that may appear in this document or any
software that may be provided in association with this document.  Except
as permitted by such license, no part of this document may be reproduced,
stored in a retrieval system, or transmitted in any form or by any means
without the express written consent of Intel Corporation.

Contents
========

- OVERVIEW
- CUSTOMER SUPPORT
- LEGAL


Overview
========
The Master FLB (BootIMG.FLB) file format has changed to allow using four 
part Device IDs when necessary to distinguish the correct NVM image for 
a device. All utilities and software are able to read older versions of 
the Master FLB. However, you must update any utilities software you use 
to a more recent version to use the new Master FLB. Please upgrade to 
the following versions (or a more recent version):

- BootUtil, v. 1.3.5.xxx
- Intel(R) Proset for Windows* Device Manager, v. 17.1.xxx
- SMASH, v2-2.0.0.58

The current version can be downloaded at Intel’s Network Products 
information website: http://www.intel.com/network

Customer Support
================

- Main Intel web support site: http://support.intel.com

- Network products information: http://www.intel.com/network


Legal / Disclaimers
===================

Copyright (C) 2012, Intel Corporation.  All rights reserved.

Intel Corporation assumes no responsibility for errors or omissions in this
document.  Nor does Intel make any commitment to update the information
contained herein.

Intel is a trademark of Intel Corporation in the U.S. and/or other countries.

* Other product and corporate names may be trademarks of other companies and
are used only for explanation and to the owners' benefit, without intent to
infringe.
