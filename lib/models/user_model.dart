class EhongUserModel {
  final String barcode;
  final String brId;
  final String empId;
  final String fname;
  final String lname;
  final String nick;
  final String tname;
  final String token;
  final String status;

  EhongUserModel({
    required this.barcode,
    required this.brId,
    required this.empId,
    required this.fname,
    required this.lname,
    required this.nick,
    required this.tname,
    required this.token,
    required this.status,
  });

  factory EhongUserModel.fromMap(Map<String, dynamic> map) {
    return EhongUserModel(
      barcode: map['barcode'] ?? '',
      brId: map['br_id'] ?? '',
      empId: map['emp_id'] ?? '',
      fname: map['fname'] ?? '',
      lname: map['lname'] ?? '',
      nick: map['nick'] ?? '',
      tname: map['tname'] ?? '',
      token: map['token'] ?? '',
      status: map['status'] ?? '',
    );
  }

  String get fullName => '$tname$fname $lname';
}
