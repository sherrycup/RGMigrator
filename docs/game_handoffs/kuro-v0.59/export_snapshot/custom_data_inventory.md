# 自定义数据与属性

原Ruby只读分析；来源、扩展字段和适配方法见data/custom_data.json。

概要：{"comment_tags":200,"diagnostics":2,"expressions":8,"floor_maps":1,"profile":"flash","record_fields":20,"sources":42}

## 源文件

| 原路径 | 字节 | SHA256 |
| --- | --- | --- |
| Data/Items.exdata | 264 | 2c0cffb407f41b59dd28b4d0bec58707f873465ca0f8afe622722548bc28371a |
| Data/Weapons.exdata | 171 | 0049be47a9837da6a29c40f20ff952cbab9ad284c70adadbacb8d3b8db5885fc |
| Data/Armors.exdata | 134 | 7e3326683f71ce12cace317c43bcea9b395c5e76a052684ad918ad6907cd3e2c |
| Data/Ornaments.exdata | 142 | 8bc9542fbfb34b9066d4146f97216b457586a05d2435e658408a66aa15a90b8e |
| Data/Deputies.txt | 24 | e822849f95ceed8ef8c893aa88122deff7e6334921ccdafe824514a88dae84b3 |
| Data/Enemies.txt | 98 | 858717a9773908a64dde37a83c5d57ea3bca81d5ca244c67a3a808d2c46c557f |
| Info/battle_system_atomic_refactor.svg | 12673 | 0cd33ed05cac2202f9609e6456df6daa36e4b4f4d9a298db8a2b131a041d2eee |
| Info/battle_system_current_flow.svg | 9719 | cd24bc4776471c4708cc54f19ee36e362baedd56541abb46560d08d9138124c9 |
| Info/battle_system_data_structures.svg | 11445 | 703a46226e59430ab95a9d5e5de8b452fdee3cb775c23e10ea4fff24f12e6cb8 |
| Info/battle_system_example_walkthrough.svg | 11780 | de9330d550344b65b5063c37432003df0c97d2267f072b37e854ee4a48364382 |
| Info/battle_system_flowchart.svg | 11119 | 7990f2b460f645696b064e05c4cd4d06fc7a59dd4c9e42766aa6fd7f1202738e |
| Info/Help/画面帮助.txt | 45 | 505d9b726f3fc0fdbebc49cbe7a825da48d8800a29390d8b65cb39af01f9dd40 |
| Info/Music/000.txt | 252 | f42789f2d89cc4c4ba97318ff12792bd865af240f4d756acdb58ec4b7638f91c |
| Info/Music/001.txt | 241 | da7f35aee4a96d93f7107b5a537a8b33577b07dd258856b7e97ef2142fc3e8b4 |
| Info/Music/002.txt | 313 | 87bc67cda23d246ef945d1769f86a2f1b0035ed461eb5f0547ab960f6dc94c04 |
| Info/Music/003.txt | 303 | 97136b04df35fed5ba0093d3a2c72e59ab71c20344592f5920deef90ecfb59ad |
| Info/Music/004.txt | 334 | 495fa5f32892e53e9bdb1f98b78ab8801f442da7c07f9ed154f5c166c33b7843 |
| Info/Music/005.txt | 254 | e021905323724d227254a2bceb2d920325fdc40578edc8d985376be9a5f416e0 |
| Info/Music/006.txt | 348 | ec0477fd92a7784bc0a6965388ef9e789b90a5484344e0c608b82ddb7ad03982 |
| Info/Music/007.txt | 318 | be14b6960fd3835df954bbe96baecc0775e821cdec35c7f48a3e2b3348d042c1 |
| Info/Music/008.txt | 318 | 800f21c8ea01fe75f456081b833ada425c74d82e1b2f08b6291d09cbec7867fd |
| Info/Music/009.txt | 316 | 416879d922841a0b19170ac03484b916c1dd81cc03c90a09c0cd748afe037187 |
| Info/Music/010.txt | 315 | 7325709e79074a43da224e245c88e1f63b16a537eefd62a89c7a46e45dc95cc8 |
| Info/Music/011.txt | 293 | 9a4bebde19eedc838aa026969ca36331c5d07eeffa2dc690479cd7143046b37c |
| Info/Music/012.txt | 365 | 8e5dc2999b4c108498b4262add817f9c35235e6bd0e5e61fbe26c9b228a21f6f |
| Info/Music/013.txt | 284 | 0d6797f5ae2d718894cf8f88e152291277d6b153849c724a6d1aaf3c8802adb9 |
| Info/Music/014.txt | 293 | 95a92db98a1b9c7ad52f086ea5a70fb1bdd65502e919257191d4d817212786e4 |
| Info/Music/015.txt | 304 | a752ac70fa1a19f6848e85cac26343232ed87192aeee8a1e263e7a86ffc5db64 |
| Info/Music/016.txt | 305 | a0b308d4490b3c6b9585474fb9795dae174d2f3b185a127eafc4350a0c642678 |
| Info/Music/017.txt | 304 | 717483525c999e1d1bfa3c399720544bf05a6f2c0e8a7d766fabde2aee03c20b |
| Info/Music/018.txt | 342 | 97bd9d94973cfd9df6e51f881eb5849a8cb8c47fe300f03394ce4c4acd188c55 |
| Info/Music/019.txt | 292 | 031f54a060b96e2e748e067e1231d7aaa96343e3c88fb1c7b992c7a74b16d02a |
| Info/Music/020.txt | 236 | 279835f3a952bf7ad048f08e58010e9d3043c70a86bc41e53ed91e009445180a |
| Info/Music/021.txt | 332 | b549c12083bf1d9270f8c80330944033850101e60118aff7595f1d4bd66f48ab |
| Info/Music/022.txt | 363 | 9d01bca3deeb314e30db003e493a08a4bcaeb8f4251fb5e334b6c47174d38df3 |
| Info/Music/023.txt | 396 | 2bb7ef09e72d71791bf30cbb4fcf6565a0ee42ecfbc9cbf3048aca0e5d3fe35d |
| Info/Music/024.txt | 370 | e29cdf7d1a63e5a3cdb3f790ede2c62874e0329483452b1edc789c90d444b72f |
| Info/Music/025.txt | 395 | e4727662be5fc0ccf1a29d9622af9f08917b205e1a337619a63594b0b61ef1ad |
| Info/Music/026.txt | 47 | 9f8ee9b089403d3082facde6364ca9ea5656a8ee377d11fcf2e378bea6513fe0 |
| Info/Music/027.txt | 47 | 9f8ee9b089403d3082facde6364ca9ea5656a8ee377d11fcf2e378bea6513fe0 |
| Info/Music/028.txt | 47 | 9f8ee9b089403d3082facde6364ca9ea5656a8ee377d11fcf2e378bea6513fe0 |
| Info/Music/999.txt | 35 | e3ee5483163b1807a53f70de16a21257ff055492349a60a93047b8ef2ef8f30d |

## 诊断

未知字段及缺失配置不替换、不删除。属性标签的战斗效果按0.45，立绘注释按0.46接入。
- external_missing: 配置文件不存在，未用其他示例文件替代：Data/Enemy.exdata {}
- external_missing: 配置文件不存在，未用其他示例文件替代：Data/Deputy.exdata {}
