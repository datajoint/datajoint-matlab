3.3.2 -- October 15, 2020
-------------------------
* Bugfix: Add blob validation for insert/update regarding sparse matrices which are not yet supported (#238) PR #241
* Bugfix: Modify update to allow nullable updates for strings/date (#211) PR #213
* Bugfix: createSchema had some issues with MySQL8 PR #213
* Update tests
* Docs: Update example related to virtual class (#199) PR #261
* Docs: Fix typos (#150, #151) PR #263, PR #262
* Upgrade packaging and installation to utilize MATLAB Toolbox i.e. `DataJoint.mltbx` PR #285
* Updated tagging scheme to drop v i.e. `v3.3.2` -> `3.3.2`. This is due to FileExchange GitHub Releases link not recognizing alphanumeric labels. See [MATLAB docs](https://www.mathworks.com/matlabcentral/about/fx/#Why_GitHub).

3.3.1 -- October 31, 2019
-------------------------
* Ability to create schema without GUI PR #155
* Support secure connections with TLS (aka SSL) (#103) PR #157, mym-PR #11, #12, #13
* Allow GUI-based password entry to avoid cleartext password from being captured in MATLAB log PR #159
* Add detailed error message if DJ012 Python-native blobs detected (#170) mYm-PR #16
* Add support for PAM connections via MariaDB's Dialog plugin (#168, #169) mYm-PR #14, #15
* Minor improvements to reuse of connection if applicable PR #166, #167
* Bugfixes (#152)

3.2.2 -- February 5, 2019
-------------------------

`Previous release notes TBD`