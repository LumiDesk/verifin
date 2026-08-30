import 'package:flutter/material.dart';

import '../app/avatar_picker.dart';
import '../app/common_widgets.dart';
import '../app/image_cropper.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import 'profile_widgets.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  final EditorExitController _exitController = EditorExitController();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _occupationController;
  late String _avatarDataUrl;
  late UserProfile _initialProfile;
  ProfileGender _gender = ProfileGender.unset;
  String _birthday = '';
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final profile = VeriFinScope.of(context).profile;
    _initialProfile = profile;
    _nicknameController = TextEditingController(text: profile.nickname);
    _bioController = TextEditingController(text: profile.bio);
    _cityController = TextEditingController(text: profile.city);
    _occupationController = TextEditingController(text: profile.occupation);
    _avatarDataUrl = profile.avatarDataUrl;
    _gender = profile.gender;
    _birthday = profile.birthday;
    _nicknameController.addListener(_handleDraftChanged);
    _bioController.addListener(_handleDraftChanged);
    _cityController.addListener(_handleDraftChanged);
    _occupationController.addListener(_handleDraftChanged);
    _initialized = true;
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_handleDraftChanged);
    _bioController.removeListener(_handleDraftChanged);
    _cityController.removeListener(_handleDraftChanged);
    _occupationController.removeListener(_handleDraftChanged);
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: AppLocalizations.of(context).personalInfo,
                  showBack: true,
                  actions: <Widget>[
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(42),
                    onTap: _pickAvatar,
                    child: ProfileAvatar(
                      profile: controller.profile.copyWith(
                        avatarDataUrl: _avatarDataUrl,
                      ),
                      radius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).nicknameLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).bioLabel,
                  ),
                ),
                const SizedBox(height: 10),
                VeriAnchoredChoice<ProfileGender>(
                  key: const Key('profile_gender_choice'),
                  values: ProfileGender.values,
                  selected: _gender,
                  idOf: (value) => 'profile_gender_${value.name}',
                  labelOf: (value) => value.label(AppLocalizations.of(context)),
                  iconOf: (value) => switch (value) {
                    ProfileGender.unset => Icons.remove_circle_outline,
                    ProfileGender.male => Icons.male_rounded,
                    ProfileGender.female => Icons.female_rounded,
                  },
                  onSelected: (value) => setState(() => _gender = value),
                  semanticLabel: AppLocalizations.of(context).pickGenderTitle,
                  width: 188,
                  builder: (context, openMenu, menuOpen) => SelectField(
                    label: AppLocalizations.of(context).genderLabel,
                    value: _gender.label(AppLocalizations.of(context)),
                    icon: Icons.person_outline,
                    onTap: openMenu,
                  ),
                ),
                const SizedBox(height: 10),
                SelectField(
                  key: const Key('profile_birthday_field'),
                  label: AppLocalizations.of(context).birthdayLabel,
                  value: _birthday.isEmpty
                      ? AppLocalizations.of(context).clearOption
                      : _birthday,
                  icon: Icons.cake_outlined,
                  suffixIcon: _birthday.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('profile_birthday_clear'),
                          tooltip: AppLocalizations.of(context).birthdayClear,
                          onPressed: _clearBirthday,
                          icon: const Icon(Icons.close),
                        ),
                  onTap: _pickBirthday,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cityController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).cityLabel,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _occupationController,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).occupationLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final initial = DateTime.tryParse(_birthday) ?? DateTime(1998);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() {
        _birthday =
            '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _clearBirthday() {
    setState(() => _birthday = '');
  }

  Future<void> _pickAvatar() async {
    final rawImage = await pickRawImageDataUrl();
    if (rawImage == null || !mounted) {
      return;
    }
    final crop = await showImageCropper(
      context: context,
      imageDataUrl: rawImage,
      title: AppLocalizations.of(context).cropAvatarTitle,
      aspectRatio: 1,
      circlePreview: true,
    );
    if (crop == null || !mounted) {
      return;
    }
    final avatar = await runWithLoadingDialog<String?>(
      context: context,
      message: AppLocalizations.of(context).avatarGenerating,
      task: () => cropImageDataUrl(
        sourceDataUrl: rawImage,
        targetWidth: 512,
        targetHeight: 512,
        zoom: crop.zoom,
        offsetX: crop.offsetX,
        offsetY: crop.offsetY,
      ),
    );
    if (avatar != null && mounted) {
      setState(() => _avatarDataUrl = avatar);
    }
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  UserProfile _draftProfile({required bool useNicknameFallback}) {
    final nickname = _nicknameController.text.trim();
    return UserProfile(
      nickname: useNicknameFallback && nickname.isEmpty ? 'Veri Fin' : nickname,
      bio: _bioController.text.trim(),
      avatarDataUrl: _avatarDataUrl,
      gender: _gender,
      birthday: _birthday,
      city: _cityController.text.trim(),
      occupation: _occupationController.text.trim(),
    );
  }

  bool get _isDirty {
    final draft = _draftProfile(useNicknameFallback: false);
    return draft.nickname != _initialProfile.nickname ||
        draft.bio != _initialProfile.bio ||
        draft.avatarDataUrl != _initialProfile.avatarDataUrl ||
        draft.gender != _initialProfile.gender ||
        draft.birthday != _initialProfile.birthday ||
        draft.city != _initialProfile.city ||
        draft.occupation != _initialProfile.occupation;
  }

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() {
        _initialProfile = _draftProfile(useNicknameFallback: true);
      });
      _exitController.exit();
    }
  }

  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context);
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.nicknameEmptyTitle,
        message: l10n.nicknameEmptyMessage,
        confirmLabel: l10n.commonSave,
      );
      if (confirmed != true || !mounted) {
        return false;
      }
    }
    return VeriFinScope.of(
      context,
    ).saveProfileDraft(_draftProfile(useNicknameFallback: true));
  }
}
