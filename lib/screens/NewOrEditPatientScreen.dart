import 'package:flutter/material.dart';
import 'package:pebrapp/components/SizedButton.dart';
import 'package:pebrapp/database/DatabaseProvider.dart';
import 'package:pebrapp/database/models/Patient.dart';
import 'package:pebrapp/state/PatientBloc.dart';
import 'package:pebrapp/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart';

class NewOrEditPatientScreen extends StatelessWidget {

  final Patient existingPatient;

  NewOrEditPatientScreen({this.existingPatient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color.fromARGB(255, 224, 224, 224),
        appBar: AppBar(
          title: existingPatient == null ?
          const Text('New Patient', key: Key('newOrEditPatientTitle'),) :
          Text('Edit Patient: ${existingPatient.artNumber}', key: Key('newOrEditPatientTitle')),
        ),
        body: Center(
          child: _NewOrEditPatientScreenBody(existingPatient),
        ));
  }
}

class _NewOrEditPatientScreenBody extends StatelessWidget {

  final Patient _existingPatient;

  _NewOrEditPatientScreenBody(this._existingPatient);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: SingleChildScrollView(child: _NewOrEditPatientForm(_existingPatient))),
    ]);
  }
}

// https://flutter.dev/docs/cookbook/forms/validation
class _NewOrEditPatientForm extends StatefulWidget {

  final Patient _existingPatient;

  _NewOrEditPatientForm(this._existingPatient);

  @override
  _NewOrEditPatientFormState createState() {
    return _NewOrEditPatientFormState(_existingPatient);
  }
}

class _NewOrEditPatientFormState extends State<_NewOrEditPatientForm> {
  // Create a global key that will uniquely identify the Form widget and allow
  // us to validate the form
  final _formKey = GlobalKey<FormState>();

  final Patient _existingPatient;
  bool _editModeOn;
  bool _patientIsActivated = false;
  TextEditingController _artNumberCtr = TextEditingController();
  TextEditingController _villageCtr = TextEditingController();
  TextEditingController _districtCtr = TextEditingController();
  TextEditingController _phoneNumberCtr = TextEditingController();

  _NewOrEditPatientFormState(this._existingPatient) {
    _editModeOn = _existingPatient != null;
    _patientIsActivated = _existingPatient?.isActivated ?? false;
    _artNumberCtr.text = _editModeOn ? _existingPatient?.artNumber : null;
    _villageCtr.text = _editModeOn ? _existingPatient?.village : null;
    _districtCtr.text = _editModeOn ? _existingPatient?.district : null;
    _phoneNumberCtr.text = _editModeOn ? _existingPatient?.phoneNumber : null;
  }

  List<String> _artNumbersInDB;
  bool get _isLoading { return _artNumbersInDB == null; }

  @override
  initState() {
    print('~~~ _NewOrEditPatientFormState.initState ~~~');
    super.initState();
    DatabaseProvider().retrievePatientsART().then((artNumbers) {
      setState(() {
        _artNumbersInDB = artNumbers;
      });
    });
  }

  @override
  void didUpdateWidget(_NewOrEditPatientForm oldWidget) {
    print('~~~ _NewOrEditPatientFormState.didUpdateWidget ~~~');
    super.didUpdateWidget(oldWidget);
  }

  @override
  void reassemble() {
    print('~~~ _NewOrEditPatientFormState.reassemble ~~~');
    super.reassemble();
  }

  @override
  void didChangeDependencies() {
    print('~~~ _NewOrEditPatientFormState.didChangeDependencies ~~~');
    super.didChangeDependencies();
  }

  @override
  void deactivate() {
    print('~~~ _NewOrEditPatientFormState.deactivate ~~~');
    super.deactivate();
  }

  @override
  void dispose() {
    print('~~~ _NewOrEditPatientFormState.dispose ~~~');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('~~~ _NewOrEditPatientFormState.build ~~~');
    // Build a Form widget using the _formKey we created above
    return Form(
      key: _formKey,
      child: Column(children: [
        Card(
          margin: EdgeInsets.all(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ART Number'),
                TextFormField(
                  enabled: !_editModeOn,
                  controller: _artNumberCtr,
                  validator: (value) {
                    if (_existingPatient != null) {
                      return null;
                    }
                    if (value.isEmpty) {
                      print('ART validation failed');
                      return 'Please enter an ART number';
                    } else if (_artNumberExists(value)) {
                      print('ART validation failed');
                      return 'This ART number exists already in the database';
                    }
                  },
                ),
                Text('Village'),
                TextFormField(
                  controller: _villageCtr,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'Please enter a village';
                    }
                  },
                ),
                Text('District'),
                TextFormField(
                  controller: _districtCtr,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'Please enter a district';
                    }
                  },
                ),
                Text('Phone Number'),
                TextFormField(
                  controller: _phoneNumberCtr,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                  },
                ),
                CheckboxListTile(
                  title: Text(
                    'Activate Patient',
                  ),
                  value: _patientIsActivated,
                  onChanged: (bool newState) {
                    setState(() { _patientIsActivated = newState; });
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: SizedButton(
              'Save',
              onPressed: _isLoading ? null : _onSubmitForm,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: SizedButton(
              'Open KoBoCollect',
              onPressed: _openKoBoCollect,
            ),
          ),
        ),
      ]),
    );
  }

  _openKoBoCollect() async {
    const appUrl = 'android-app://org.koboc.collect.android';
    const marketUrl = 'market://details?id=org.koboc.collect.android';
    if (await canLaunch(appUrl)) {
      await launch(appUrl);
    } else if (await canLaunch(marketUrl)) {
      await launch(marketUrl);
    } else {
      showFlushBar(context, "Could not find KoBoCollect app. Make sure KoBoCollect is installed.");
    }
  }

  _onSubmitForm() async {
    Patient newPatient;
    // Validate will return true if the form is valid, or false if the form is invalid.
    if (_formKey.currentState.validate()) {
      if (_editModeOn) { // editing an existing patient
        newPatient = _existingPatient;
        newPatient.village = _villageCtr.text;
        newPatient.district = _districtCtr.text;
        newPatient.phoneNumber = _phoneNumberCtr.text;
        newPatient.isActivated = _patientIsActivated;
        print('EDITED PATIENT:\n$newPatient');
      } else { // creating a new patient
        newPatient = Patient(_artNumberCtr.text, _districtCtr.text, _phoneNumberCtr.text, _villageCtr.text, _patientIsActivated);
        print('NEW PATIENT:\n$newPatient');
      }
      await PatientBloc.instance.sinkPatientData(newPatient);
      Navigator.of(context).popUntil((Route<dynamic> route) {
        return (route.settings.name == '/patient' || route.settings.name == '/');
      });
      final String finishNotification = _editModeOn
          ? 'Changes saved'
          : 'New patient created successfully';
      showFlushBar(context, finishNotification);
    }
  }

  bool _artNumberExists(artNumber) {
    return _artNumbersInDB.contains(artNumber);
  }

}
