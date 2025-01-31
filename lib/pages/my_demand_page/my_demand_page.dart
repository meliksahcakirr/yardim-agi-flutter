import 'package:deprem_destek/data/models/demand.dart';
import 'package:deprem_destek/data/repository/auth_repository.dart';
import 'package:deprem_destek/data/repository/demands_repository.dart';
import 'package:deprem_destek/pages/my_demand_page/state/my_demands_cubit.dart';
import 'package:deprem_destek/pages/my_demand_page/state/my_demands_state.dart';
import 'package:deprem_destek/pages/my_demand_page/widgets/demand_category_selector.dart';
import 'package:deprem_destek/pages/my_demand_page/widgets/geo_value_accessor.dart';
import 'package:deprem_destek/pages/my_demand_page/widgets/my_demand_textfield.dart';
import 'package:deprem_destek/shared/extensions/reactive_forms_extensions.dart';
import 'package:deprem_destek/shared/state/app_cubit.dart';
import 'package:deprem_destek/shared/widgets/loader.dart';
import 'package:deprem_destek/shared/widgets/snackbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_geocoding_api/google_geocoding_api.dart';
import 'package:reactive_forms/reactive_forms.dart';

class MyDemandPage extends StatefulWidget {
  const MyDemandPage._();

  static Future<void> show(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return BlocProvider<MyDemandsCubit>(
            create: (context) => MyDemandsCubit(
              demandsRepository: context.read<DemandsRepository>(),
            ),
            child: const MyDemandPage._(),
          );
        },
      ),
    );
  }

  @override
  State<MyDemandPage> createState() => _MyDemandPageState();
}

class _MyDemandPageState extends State<MyDemandPage> {
  final FormGroup _myDemandPageFormGroup = FormGroup({
    _MyDemandPageFormFields.geoLocation.name:
        FormControl<GoogleGeocodingResult>(),
    _MyDemandPageFormFields.categories.name: FormControl<List<String>>(
      validators: [
        Validators.minLength(1),
      ],
      value: [],
    ),
    _MyDemandPageFormFields.notes.name: FormControl<String>(
      validators: [Validators.required],
    ),
    _MyDemandPageFormFields.notes.name:
        FormControl<String>(validators: [Validators.required]),
    _MyDemandPageFormFields.phoneNumber.name: FormControl<String>(
      validators: [Validators.required, Validators.minLength(13)],
    ),
    _MyDemandPageFormFields.wpPhoneNumber.name: FormControl<String>(),
  });

  @override
  void initState() {
    super.initState();
    final location = context.read<AppCubit>().state.whenOrNull(
          loaded: (currentLocation, demandCategories) => currentLocation,
        );

    _myDemandPageFormGroup
        .control(_MyDemandPageFormFields.geoLocation.name)
        .value = location;

    _myDemandPageFormGroup
        .control(_MyDemandPageFormFields.phoneNumber.name)
        .value = FirebaseAuth.instance.currentUser?.phoneNumber;

    _myDemandPageFormGroup
        .control(_MyDemandPageFormFields.wpPhoneNumber.name)
        .value = FirebaseAuth.instance.currentUser?.phoneNumber;
  }

  void _onToggleActivation({required Demand demand}) {
    if (demand.isActive) {
      context.read<MyDemandsCubit>().deactivateDemand(
            demandId: demand.id,
          );
    } else {
      context.read<MyDemandsCubit>().activateDemand(
            demandId: demand.id,
          );
    }
  }

  void _onSave({required String? demandId}) {
    final categories = _myDemandPageFormGroup.readByControlName<List<String>>(
      _MyDemandPageFormFields.categories.name,
    );
    final geo = _myDemandPageFormGroup.readByControlName<GoogleGeocodingResult>(
      _MyDemandPageFormFields.geoLocation.name,
    );

    final notes = _myDemandPageFormGroup.readByControlName<String>(
      _MyDemandPageFormFields.notes.name,
    );

    final phoneNumber = _myDemandPageFormGroup.readByControlName<String>(
      _MyDemandPageFormFields.phoneNumber.name,
    );

    final whatsappNumber = _myDemandPageFormGroup
            .control(
              _MyDemandPageFormFields.wpPhoneNumber.name,
            )
            .enabled
        ? _myDemandPageFormGroup.readByControlName<String>(
            _MyDemandPageFormFields.wpPhoneNumber.name,
          )
        : null;

    if (demandId == null) {
      context.read<MyDemandsCubit>().addDemand(
            categoryIds: categories,
            geo: geo,
            notes: notes,
            phoneNumber: phoneNumber,
            whatsappNumber: whatsappNumber,
          );
    } else {
      context.read<MyDemandsCubit>().updateDemand(
            demandId: demandId,
            categoryIds: categories,
            geo: geo,
            notes: notes,
            phoneNumber: phoneNumber,
            whatsappNumber: whatsappNumber,
          );
    }
  }

  void _populateWithExistingData({required Demand? existingDemand}) {
    if (existingDemand != null) {
      _myDemandPageFormGroup
          .control(_MyDemandPageFormFields.categories.name)
          .value = existingDemand.categoryIds;
      _myDemandPageFormGroup.control(_MyDemandPageFormFields.notes.name).value =
          existingDemand.notes;
    }
  }

  void _listener(BuildContext context, MyDemandState state) {
    state.status.whenOrNull(
      loadedCurrentDemand: () {
        _populateWithExistingData(existingDemand: state.demand);
      },
      loadFailed: () {
        const AppSnackbars.failure('Sayfa yüklemesi başarısız.').show(context);
      },
      saveFail: () {
        const AppSnackbars.failure('Kaydetme başarısız.').show(context);
      },
      saveSuccess: () {
        const AppSnackbars.success('Değişiklikler kaydedildi.').show(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppCubit>().state.mapOrNull(
          loaded: (loadedAppState) => loadedAppState,
        );

    if (appState == null) {
      return const Scaffold(body: Loader());
    }

    return BlocConsumer<MyDemandsCubit, MyDemandState>(
      listener: _listener,
      builder: (context, state) {
        final deactivateButtons =
            state.status.maybeWhen(saving: () => true, orElse: () => false);

        return state.status.maybeWhen(
          loadingCurrentDemand: () => const Scaffold(body: Loader()),
          orElse: () => Scaffold(
            appBar: AppBar(
              title: const Text('Talep Ekle/Düzenle'),
            ),
            body: SingleChildScrollView(
              child: ReactiveForm(
                formGroup: _myDemandPageFormGroup,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReactiveTextField<GoogleGeocodingResult>(
                        formControlName:
                            _MyDemandPageFormFields.geoLocation.name,
                        decoration: InputDecoration(
                          labelText: 'Adres',
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(width: 2),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(width: 2),
                          ),
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                        ),
                        valueAccessor: GeoValueAccessor(),
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Adresiniz bizim için gerekli',
                          ValidationMessage.any: (_) =>
                              'Lütfen geçerli bir adres giriniz.',
                        },
                      ),
                      DemandCategorySelector(
                        formControl: _myDemandPageFormGroup.control(
                          _MyDemandPageFormFields.categories.name,
                        ) as FormControl<List<String>>,
                      ),
                      MyDemandsTextField<String>(
                        labelText: 'Neye İhtiyacın Var?',
                        isLongBody: true,
                        formControlName: _MyDemandPageFormFields.notes.name,
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Neye ihtiyacınız olduğunu yazar mısınız?.',
                        },
                      ),
                      MyDemandsTextField<String>(
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(
                              '[+0-9]',
                            ),
                          ),
                        ],
                        labelText: 'Telefon Numarası',
                        formControlName:
                            _MyDemandPageFormFields.phoneNumber.name,
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Whats App numaranız gerekli.',
                          ValidationMessage.number: (_) =>
                              'Whats App Numaranız geçerli olmalı',
                        },
                      ),
                      MyDemandsTextField<String>(
                        labelText: 'WhatsApp',
                        formControlName:
                            _MyDemandPageFormFields.wpPhoneNumber.name,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(
                              '[+0-9]',
                            ),
                          ),
                        ],
                        validationMessages: {
                          ValidationMessage.required: (_) =>
                              'Numaranız gerekli.',
                          ValidationMessage.number: (_) =>
                              'Numaranız geçerli olmalı',
                        },
                      ),
                      ReactiveFormConsumer(
                        builder: (context, form, _) {
                          return CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            value: form
                                .control(
                                  _MyDemandPageFormFields.wpPhoneNumber.name,
                                )
                                .enabled,
                            onChanged: (value) => value != true
                                ? form
                                    .control(
                                      _MyDemandPageFormFields
                                          .wpPhoneNumber.name,
                                    )
                                    .markAsDisabled()
                                : form
                                    .control(
                                      _MyDemandPageFormFields
                                          .wpPhoneNumber.name,
                                    )
                                    .markAsEnabled(),
                            title: Row(
                              children: const [
                                Text('Whatsapp ile ulaşılsın'),
                                SizedBox(
                                  width: 8,
                                ),
                                Icon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      MyDemandsTextField<String>(
                        labelText: 'Whatsapp Numarası',
                        formControlName:
                            _MyDemandPageFormFields.wpPhoneNumber.name,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(13),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        child: ReactiveFormConsumer(
                          builder: (context, formGroup, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed:
                                        formGroup.valid && !deactivateButtons
                                            ? () => _onSave(
                                                  demandId: state.demand?.id,
                                                )
                                            : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Text(
                                        state.demand == null
                                            ? 'Talep Oluştur'
                                            : 'Talebi Güncelle',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (state.demand != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: !deactivateButtons
                                          ? () => _onToggleActivation(
                                                demand: state.demand!,
                                              )
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Text(
                                          state.demand!.isActive
                                              ? 'Talebi durdur'
                                              : 'Talebi sürdür',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<AuthRepository>().logout();
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Çıkış yap',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _MyDemandPageFormFields {
  geoLocation,
  categories,
  notes,
  phoneNumber,
  wpPhoneNumber,
}
