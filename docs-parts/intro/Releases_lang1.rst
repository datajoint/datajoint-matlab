3.4.0 -- December 9, 2020
-------------------------
* Minor: Add dj.config to be compatible with dj-python and removet dj.set (#186) #188
* Minor: Add UUID DataJoint datatype (#180) PR #194
* Minor: Add file external storage (#143) PR #197
* Minor: Add S3 external storage (#88) PR #207
* Minor: Improve dependency version compatibility handling (#228) PR #285
* Minor: Add unique and nullable options for foreign keys (#110) PR #303
* Minor: Add non-interactive option for dj.new (#69) #317
* Bugfix: Handle empty password (#250) PR #279, #292
* Bugfix: Disable GUI password if running headless (#278) PR #280, #292
* Bugfix: Fix order to dj.kill output (#229) PR #248, #292
* Bugfix: erd function missing from package (#307) PR #310
* Bugfix: Error on extremely short table names (#311) PR #317
* Bugfix: Incorrect return when fetchn of an external field (#269) PR #274
* Bugfix: MATLAB crashes randomly on insert 8-byte string (#255) PR #257
* Bugfix: Errors thrown when seeing unsupported DataJoint types (#254) PR #265
* Bugfix: Fix SQL argument growth condition on blobs (#217) PR #220
* Tests: Add R2016b tests (#233) PR #235
* Tests: Convert testing framework from TravisCI to GitHub Actions (#320) PR #317
* Tests: Increase test coverage

3.3.2 -- October 15, 2020
-------------------------
* Bugfix: Add blob validation for insert/update regarding sparse matrices which are not yet supported (#238) PR #241
* Bugfix: Modify update to allow nullable updates for strings/date (#211) PR #213
* Bugfix: createSchema had some issues with MySQL8 PR #213
* Update tests
* Docs: Update example related to virtual class (#199) PR #261
* Docs: Fix typos (#150, #151) PR #263, PR #262
* Upgrade packaging and installation to utilize MATLAB Toolbox i.e. `DataJoint.mltbx` PR #285

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