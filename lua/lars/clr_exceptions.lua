-- Curated list of common BCL exception types, fully qualified.
-- Used as the default population for the <Leader>de picker.
-- Project-local exceptions are merged on top via the discovery
-- module. Names must match what netcoredbg sees at runtime —
-- it compares against the full type name including namespace.

return {
	-- System
	"System.AccessViolationException",
	"System.AggregateException",
	"System.ApplicationException",
	"System.ArgumentException",
	"System.ArgumentNullException",
	"System.ArgumentOutOfRangeException",
	"System.ArithmeticException",
	"System.ArrayTypeMismatchException",
	"System.BadImageFormatException",
	"System.DivideByZeroException",
	"System.DllNotFoundException",
	"System.EntryPointNotFoundException",
	"System.Exception",
	"System.FieldAccessException",
	"System.FormatException",
	"System.IndexOutOfRangeException",
	"System.InvalidCastException",
	"System.InvalidOperationException",
	"System.MemberAccessException",
	"System.MethodAccessException",
	"System.MissingFieldException",
	"System.MissingMemberException",
	"System.MissingMethodException",
	"System.NotImplementedException",
	"System.NotSupportedException",
	"System.NullReferenceException",
	"System.ObjectDisposedException",
	"System.OperationCanceledException",
	"System.OutOfMemoryException",
	"System.OverflowException",
	"System.PlatformNotSupportedException",
	"System.RankException",
	"System.StackOverflowException",
	"System.SystemException",
	"System.TimeoutException",
	"System.TypeAccessException",
	"System.TypeInitializationException",
	"System.TypeLoadException",
	"System.UnauthorizedAccessException",

	-- System.Collections.Generic
	"System.Collections.Generic.KeyNotFoundException",

	-- System.IO
	"System.IO.DirectoryNotFoundException",
	"System.IO.DriveNotFoundException",
	"System.IO.EndOfStreamException",
	"System.IO.FileLoadException",
	"System.IO.FileNotFoundException",
	"System.IO.IOException",
	"System.IO.PathTooLongException",

	-- System.Net
	"System.Net.CookieException",
	"System.Net.HttpListenerException",
	"System.Net.WebException",
	"System.Net.Http.HttpRequestException",
	"System.Net.Sockets.SocketException",

	-- System.Threading
	"System.Threading.AbandonedMutexException",
	"System.Threading.LockRecursionException",
	"System.Threading.SemaphoreFullException",
	"System.Threading.SynchronizationLockException",
	"System.Threading.ThreadAbortException",
	"System.Threading.ThreadInterruptedException",
	"System.Threading.ThreadStateException",
	"System.Threading.Tasks.TaskCanceledException",
	"System.Threading.Tasks.TaskSchedulerException",

	-- System.Data
	"System.Data.ConstraintException",
	"System.Data.DataException",
	"System.Data.Common.DbException",
	"System.Data.SqlClient.SqlException",
	"Microsoft.Data.SqlClient.SqlException",

	-- System.Reflection
	"System.Reflection.AmbiguousMatchException",
	"System.Reflection.ReflectionTypeLoadException",
	"System.Reflection.TargetException",
	"System.Reflection.TargetInvocationException",
	"System.Reflection.TargetParameterCountException",

	-- System.Runtime.InteropServices
	"System.Runtime.InteropServices.COMException",
	"System.Runtime.InteropServices.ExternalException",
	"System.Runtime.InteropServices.SEHException",

	-- System.Runtime.Serialization
	"System.Runtime.Serialization.SerializationException",

	-- System.Security
	"System.Security.SecurityException",
	"System.Security.Authentication.AuthenticationException",
	"System.Security.Cryptography.CryptographicException",

	-- System.Text
	"System.Text.DecoderFallbackException",
	"System.Text.EncoderFallbackException",
	"System.Text.RegularExpressions.RegexMatchTimeoutException",

	-- System.Xml
	"System.Xml.XmlException",
	"System.Xml.Schema.XmlSchemaException",

	-- Microsoft.CSharp
	"Microsoft.CSharp.RuntimeBinder.RuntimeBinderException",
}
