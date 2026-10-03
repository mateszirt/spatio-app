import '../../domain/models/app_user.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../datasources/user_remote_data_source.dart';

class UserRepositoryImpl implements IUserRepository {
  final IUserRemoteDataSource _remoteDataSource;

  UserRepositoryImpl(IUserRemoteDataSource remoteDataSource)
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<AppUser>> getUsersByHousehold(String householdId) {
    return _remoteDataSource.fetchUsers(householdId);
  }

  @override
  Future<int> getEffortPoints(String userId, {required DateTime since}) {
    return _remoteDataSource.fetchEffortPoints(userId, since: since);
  }
}
