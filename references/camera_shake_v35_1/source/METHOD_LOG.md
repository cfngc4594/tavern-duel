# 原死亡震动：assembly-scoped方法证据

仅静态解析原文件，未加载或运行原客户端。REA6.8.0身份/类型库存是partial：64MiB representation budget；完整指令来自dnfile/dncil独立解析，不能声称REA完整反编译。

## camera_shake

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x0601507f CameraShakeMgr::get_IsCameraShaking RVA 0x62f0bc (7 CIL bytes)
- 0x06015080 CameraShakeMgr::Update RVA 0x62f0c4 (45 CIL bytes)
- 0x06015081 CameraShakeMgr::Shake RVA 0x62f0f4 (82 CIL bytes)
- 0x06015082 CameraShakeMgr::Shake RVA 0x62f154 (41 CIL bytes)
- 0x06015083 CameraShakeMgr::Stop RVA 0x62f18c (99 CIL bytes)
- 0x06015084 CameraShakeMgr::IsShaking RVA 0x62f1fc (29 CIL bytes)
- 0x06015085 CameraShakeMgr::DoesCurveHaveZeroTime RVA 0x62f228 (48 CIL bytes)
- 0x06015086 CameraShakeMgr::StartShake RVA 0x62f264 (135 CIL bytes)
- 0x06015087 CameraShakeMgr::StopShake RVA 0x62f2f8 (70 CIL bytes)
- 0x06015088 CameraShakeMgr::UpdateShake RVA 0x62f34c (194 CIL bytes)
- 0x06015089 CameraShakeMgr::ComputeIntensity RVA 0x62f41a (32 CIL bytes)
- 0x0601508a CameraShakeMgr::IsHolding RVA 0x62f43c (49 CIL bytes)
- 0x0601508b CameraShakeMgr::.ctor RVA 0x24e0 (7 CIL bytes)
- 0x0601508c CameraShaker::StartShake RVA 0x62f47c (59 CIL bytes)
- 0x0601508d CameraShaker::.ctor RVA 0x24e0 (7 CIL bytes)

## shake_actions

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06016bde HutongGames.PlayMaker.Actions.MainCameraShakerAction::OnEnter RVA 0x69f5cb (19 CIL bytes)
- 0x06016bdf HutongGames.PlayMaker.Actions.MainCameraShakerAction::OnUpdate RVA 0x69f5e0 (106 CIL bytes)
- 0x06016be0 HutongGames.PlayMaker.Actions.MainCameraShakerAction::Shake RVA 0x69f656 (40 CIL bytes)
- 0x06016be1 HutongGames.PlayMaker.Actions.MainCameraShakerAction::.ctor RVA 0x53731a (7 CIL bytes)
- 0x06016c7a HutongGames.PlayMaker.Actions.ShakeMinionsAction::OnEnter RVA 0x6a16bd (13 CIL bytes)
- 0x06016c7b HutongGames.PlayMaker.Actions.ShakeMinionsAction::DoShakeMinions RVA 0x6a16cc (219 CIL bytes)
- 0x06016c7c HutongGames.PlayMaker.Actions.ShakeMinionsAction::.ctor RVA 0x6a17b3 (21 CIL bytes)

## camera_ownership

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06011d73 CameraManager::set_BaseCamera RVA 0x537a7c (152 CIL bytes)
- 0x06011d74 CameraManager::Get RVA 0x537b20 (23 CIL bytes)
- 0x06011d75 CameraManager::IsInitialized RVA 0x537b38 (9 CIL bytes)
- 0x06011d76 CameraManager::Initialize RVA 0x537b42 (14 CIL bytes)
- 0x06011d77 CameraManager::GetDependencies RVA 0x108c71 (2 CIL bytes)
- 0x06011d78 CameraManager::Shutdown RVA 0x537b51 (7 CIL bytes)
- 0x06011d79 CameraManager::.ctor RVA 0x3159 (7 CIL bytes)
- 0x06012c6f BoardCameras::Awake RVA 0x57a810 (36 CIL bytes)
- 0x06012c70 BoardCameras::OnDestroy RVA 0x57a835 (7 CIL bytes)
- 0x06012c71 BoardCameras::Get RVA 0x57a83d (6 CIL bytes)
- 0x06012c72 BoardCameras::GetAudioListener RVA 0x57a844 (7 CIL bytes)
- 0x06012c73 BoardCameras::GetCamera RVA 0x57a84c (12 CIL bytes)
- 0x06012c74 BoardCameras::TweenCameraFieldOfView RVA 0x57a859 (28 CIL bytes)
- 0x06012c75 BoardCameras::GetCameras RVA 0x57a876 (12 CIL bytes)
- 0x06012c76 BoardCameras::.ctor RVA 0x57a883 (29 CIL bytes)
- 0x06014684 MainCamera::Awake RVA 0x60a240 (108 CIL bytes)
- 0x06014685 MainCamera::OnDestroy RVA 0x60a2b8 (19 CIL bytes)
- 0x06014686 MainCamera::.ctor RVA 0x24e0 (7 CIL bytes)

## camera_lookup_semantics

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06014c07 CameraUtils::FindFirstByLayer RVA 0x61e757 (17 CIL bytes)
- 0x06014c08 CameraUtils::FindFirstByLayer RVA 0x61e769 (17 CIL bytes)
- 0x06014c09 CameraUtils::FindFirstByLayerMask RVA 0x61e77c (93 CIL bytes)
- 0x06014c0a CameraUtils::FindProjectionCameraForObject RVA 0x61e7e5 (30 CIL bytes)

## board_camera_parenting

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06005826 Gameplay::OnBoardLoaded RVA 0x198f90 (352 CIL bytes)
- 0x06005828 Gameplay::OnBoardCamerasLoaded RVA 0x199108 (159 CIL bytes)
- 0x0600582a Gameplay::OnBoardLayoutLoaded RVA 0x199244 (170 CIL bytes)
- 0x0600582c Gameplay::OnEndTurnButtonLoaded RVA 0x199358 (196 CIL bytes)

## ui_camera_initialization

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06011d7c <Initialize>d__11::MoveNext RVA 0x537b68 (source caller CIL bytes)

## mana_ownership

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06005b30 ManaCrystalMgr::Awake RVA 0x1abfbe (38 CIL bytes)
- 0x06005b32 ManaCrystalMgr::Start RVA 0x1abff8 (29 CIL bytes)
- 0x06005b56 ManaCrystalMgr::UpdateLayout RVA 0x1acacc (344 CIL bytes)
- 0x06005b58 ManaCrystalMgr::LoadCrystalCallback RVA 0x1acc40 (420 CIL bytes)

## hidden_hand_loading

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06012e11 Card::FinishActorLoad RVA 0x58383d (53 CIL bytes)
- 0x06012e12 Card::ForceLoadHandActor RVA 0x583874 (336 CIL bytes)
- 0x06012e9b Card::DetermineActorPathForZone RVA 0x588670 (58 CIL bytes)

## minion_shake

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x060152d6 MinionShake::Awake RVA 0x63beb7 (12 CIL bytes)
- 0x060152d7 MinionShake::LateUpdate RVA 0x63bec4 (229 CIL bytes)
- 0x060152d8 MinionShake::OnDestroy RVA 0x63bfb5 (25 CIL bytes)
- 0x060152d9 MinionShake::isShaking RVA 0x63bfcf (7 CIL bytes)
- 0x060152da MinionShake::ShakeAllMinions RVA 0x63bfd8 (99 CIL bytes)
- 0x060152db MinionShake::ShakeTargetMinion RVA 0x63c048 (133 CIL bytes)
- 0x060152dc MinionShake::ShakeObject RVA 0x63c0d9 (17 CIL bytes)
- 0x060152dd MinionShake::ShakeObject RVA 0x63c0ec (19 CIL bytes)
- 0x060152de MinionShake::ShakeObject RVA 0x63c10c (115 CIL bytes)
- 0x060152df MinionShake::ShakeAllMinionsRandomMedium RVA 0x63c18c (79 CIL bytes)
- 0x060152e0 MinionShake::ShakeAllMinionsRandomLarge RVA 0x63c1e8 (79 CIL bytes)
- 0x060152e1 MinionShake::RandomShake RVA 0x63c243 (35 CIL bytes)
- 0x060152e2 MinionShake::ShakeMinion RVA 0x63c268 (680 CIL bytes)
- 0x060152e3 MinionShake::AngleToVector RVA 0x63c51c (60 CIL bytes)
- 0x060152e4 MinionShake::StartShakeAnimation RVA 0x63c564 (14 CIL bytes)
- 0x060152e5 MinionShake::ResetShakeAnimator RVA 0x63c573 (14 CIL bytes)
- 0x060152e6 MinionShake::FindAllMinionShakers RVA 0x63c584 (267 CIL bytes)
- 0x060152e7 MinionShake::.ctor RVA 0x63c6c4 (58 CIL bytes)
- 0x060152e8 MinionShake::.cctor RVA 0x63c6ff (16 CIL bytes)

## minion_shake_coroutines

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x060152eb <ResetShakeAnimator>d__39::MoveNext RVA 0x63c720 (151 CIL bytes)
- 0x060152f1 <StartShakeAnimation>d__38::MoveNext RVA 0x63c7dc (89 CIL bytes)

## minion_death_itween

Assembly: v30_work/original_code/Blizzard.T5.iTween.dll
SHA256: 35702517648b33a463b6f061478787c30cba28555bf2178cc5cafbda56fb660d

- 0x06000022 iTween::ShakePosition RVA 0x33f4 (52 CIL bytes)
- 0x06000023 iTween::ShakePosition RVA 0x3429 (40 CIL bytes)
- 0x0600003f iTween::GenerateShakePositionTargets RVA 0x5a78 (312 CIL bytes)
- 0x06000054 iTween::ApplyShakePositionTargets RVA 0x757c (481 CIL bytes)

## minion_death_action

Assembly: v30_work/original_code/Blizzard.T5.PlayMakerCustomActions.Runtime.dll
SHA256: 493a17ad4e44253295567453c0da9d1089f32b168921cef70fc58f159eae94d2

- 0x060001c9 HutongGames.PlayMaker.Actions.iTweenShakePosition::Reset RVA 0xbe50 (96 CIL bytes)
- 0x060001ca HutongGames.PlayMaker.Actions.iTweenShakePosition::OnEnter RVA 0xbebc (28 CIL bytes)
- 0x060001cb HutongGames.PlayMaker.Actions.iTweenShakePosition::OnExit RVA 0xbed9 (13 CIL bytes)
- 0x060001cc HutongGames.PlayMaker.Actions.iTweenShakePosition::DoiTween RVA 0xbee8 (459 CIL bytes)
- 0x060001cd HutongGames.PlayMaker.Actions.iTweenShakePosition::.ctor RVA 0x9e13 (7 CIL bytes)

## extra_ui_ownership

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x0600592b HistoryManager::FadeVignetteIn RVA 0x19f3e4 (99 CIL bytes)
- 0x0600592c HistoryManager::FadeVignetteOut RVA 0x19f464 (97 CIL bytes)
- 0x0600592d HistoryManager::OnFullScreenEffectOutFinished RVA 0x19f4e4 (79 CIL bytes)
- 0x06005d29 NameBanner::Initialize RVA 0x1bc444 (240 CIL bytes)
- 0x06005d31 NameBanner::UpdateAnchor RVA 0x1bc630 (185 CIL bytes)

## overlay_ui_ownership

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06006305 <InstantiateTurnStartIndicator>d__31::MoveNext RVA 0x1e28e8 (232 CIL bytes)
- 0x06015e55 OverlayUI::Awake RVA 0x66ef38 (91 CIL bytes)
- 0x06015e59 OverlayUI::AddGameObject RVA 0x66effc (49 CIL bytes)
- 0x06016042 TurnStartIndicator::Start RVA 0x678574 (117 CIL bytes)
- 0x06016045 TurnStartIndicator::Show RVA 0x678600 (525 CIL bytes)

## name_banner_loading

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06005835 Gameplay::OnPlayerBannerLoaded RVA 0x199714 (288 CIL bytes)
- 0x06005838 Gameplay::OnTransitionFinished RVA 0x1998f0 (516 CIL bytes)

## name_anchor_semantics

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x060054a8 GameEntity::NameBannerPosition RVA 0x18c7e8 (46 CIL bytes)
- 0x06015002 TransformUtil::AttachAndPreserveLocalTransform RVA 0x62cffc (22 CIL bytes)
- 0x06015e52 CanvasAnchors::GetAnchor RVA 0x66ec14 (105 CIL bytes)

## result_screen_ownership

Assembly: v30_work/original_code/Assembly-CSharp.dll
SHA256: 7f81d2ab2277958dea4351c41812921a00ee263a6a7abf1a5cfb4eb0794f26e5

- 0x06004cc8 EndGameScreen::Get RVA 0x1660c6 (6 CIL bytes)
- 0x06004ce9 EndGameScreen::ShowScoreScreen RVA 0x166b7c (161 CIL bytes)
- 0x06004d8d EndGameTwoScoop::Start RVA 0x168a70 (60 CIL bytes)
