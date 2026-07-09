import 'package:flutter/material.dart';

import '../app/avatar_picker.dart';
import '../app/common_widgets.dart';
import '../app/image_cropper.dart';
import '../l10n/app_localizations.dart';
import '../app/models.dart';
import '../app/veri_fin_scope.dart';
import 'profile_widgets.dart';
import 'sheets.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _occupationController;
  late String _avatarDataUrl;
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
    _nicknameController = TextEditingController(text: profile.nickname);
    _bioController = TextEditingController(text: profile.bio);
    _cityController = TextEditingController(text: profile.city);
    _occupationController = TextEditingController(text: profile.occupation);
    _avatarDataUrl = profile.avatarDataUrl;
    _gender = profile.gender;
    _birthday = profile.birthday;
    _initialized = true;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            children: <Widget>[
              VeriHeader(
                title: AppLocalizations.of(context).personalInfo,
                showBack: true,
                actions: <Widget>[
                  HeaderAction(
                    icon: Icons.check,
                    tooltip: AppLocalizations.of(context).commonSave,
                    onPressed: _save,
                  ),
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
              SelectField(
                label: AppLocalizations.of(context).genderLabel,
                value: _gender.label(AppLocalizations.of(context)),
                icon: Icons.person_outline,
                onTap: _pickGender,
              ),
              const SizedBox(height: 10),
              SelectField(
                label: AppLocalizations.of(context).birthdayLabel,
                value: _birthday.isEmpty
                    ? AppLocalizations.of(context).clearOption
                    : _birthday,
                icon: Icons.cake_outlined,
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
    );
  }

  Future<void> _pickGender() async {
    final selected = await showOptionSheet<ProfileGender>(
      context: context,
      title: AppLocalizations.of(context).pickGenderTitle,
      values: ProfileGender.values,
      selected: _gender,
      labelOf: (value) => value.label(AppLocalizations.of(context)),
    );
    if (selected != null && mounted) {
      setState(() => _gender = selected);
    }
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.nicknameEmptyTitle),
          content: Text(l10n.nicknameEmptyMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    VeriFinScope.of(context).updateProfile(
      UserProfile(
        nickname: nickname.isEmpty ? 'Veri Fin' : nickname,
        bio: _bioController.text.trim(),
        avatarDataUrl: _avatarDataUrl,
        gender: _gender,
        birthday: _birthday,
        city: _cityController.text.trim(),
        occupation: _occupationController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }
}
